import Foundation
import ZIPFoundation

enum XLSXError: LocalizedError {
    case invalidFile
    case noData
    case noTransactions

    var errorDescription: String? {
        switch self {
        case .invalidFile: "Die Datei konnte nicht als Excel-Arbeitsmappe (.xlsx) gelesen werden."
        case .noData: "Die Datei enthält keine Daten."
        case .noTransactions: "Weder ein Jahresplan (Posten als Zeilen, Monate Januar–Dezember als Spalten) noch eine Buchungsliste (Spalten Datum und Betrag) gefunden."
        }
    }
}

enum CellValue: Equatable {
    case empty
    case text(String)
    case number(Double)
    case bool(Bool)

    var string: String {
        switch self {
        case .empty: ""
        case .text(let s): s.trimmingCharacters(in: .whitespacesAndNewlines)
        case .number(let n): n == n.rounded() && abs(n) < 1e15 ? String(Int(n)) : String(n)
        case .bool(let b): b ? "WAHR" : "FALSCH"
        }
    }

    var isEmpty: Bool { string.isEmpty }
}

struct Worksheet {
    let name: String
    var rows: [[CellValue]]
}

/// Liest alle Tabellenblätter einer .xlsx-Datei als Zellwerte (ohne Formatierung).
enum XLSXReader {
    static func read(url: URL) throws -> [Worksheet] {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw XLSXError.invalidFile
        }

        func part(_ path: String) throws -> Data? {
            guard let entry = archive[path] else { return nil }
            var data = Data()
            _ = try archive.extract(entry) { data.append($0) }
            return data
        }

        guard let workbookData = try part("xl/workbook.xml") else { throw XLSXError.invalidFile }
        let workbook = try XNode.parse(workbookData)

        // Relationship-ID -> Pfad des Blatts
        var targets: [String: String] = [:]
        if let relsData = try part("xl/_rels/workbook.xml.rels") {
            for rel in try XNode.parse(relsData).descendants("Relationship") {
                guard let id = rel.attributes["Id"], var target = rel.attributes["Target"] else { continue }
                if target.hasPrefix("/") {
                    target.removeFirst()
                } else {
                    target = "xl/" + target
                }
                targets[id] = target
            }
        }

        var sharedStrings: [String] = []
        if let sstData = try part("xl/sharedStrings.xml") {
            sharedStrings = try XNode.parse(sstData).children("si").map(Self.text(ofStringItem:))
        }

        var sheets: [Worksheet] = []
        for (index, sheet) in workbook.descendants("sheet").enumerated() {
            let name = sheet.attributes["name"] ?? "Blatt \(index + 1)"
            let path = sheet.attributes["id"].flatMap { targets[$0] } ?? "xl/worksheets/sheet\(index + 1).xml"
            guard let data = try part(path) else { continue }
            let rows = try parseSheet(XNode.parse(data), sharedStrings: sharedStrings)
            sheets.append(Worksheet(name: name, rows: rows))
        }
        return sheets
    }

    /// Text eines <si>/<is>-Elements: einfacher <t> oder Rich-Text-Runs <r><t>, ohne Phonetik (<rPh>).
    private static func text(ofStringItem node: XNode) -> String {
        if let t = node.child("t") { return t.text }
        return node.children("r").compactMap { $0.child("t")?.text }.joined()
    }

    private static func parseSheet(_ root: XNode, sharedStrings: [String]) throws -> [[CellValue]] {
        guard let sheetData = root.child("sheetData") else { return [] }
        var rows: [[CellValue]] = []
        for row in sheetData.children("row") {
            var values: [CellValue] = []
            for cell in row.children("c") {
                let column = cell.attributes["r"].flatMap(columnIndex(fromReference:)) ?? values.count
                let value = cellValue(cell, sharedStrings: sharedStrings)
                if column >= values.count {
                    values.append(contentsOf: Array(repeating: .empty, count: column - values.count + 1))
                }
                values[column] = value
            }
            rows.append(values)
        }
        return rows
    }

    private static func cellValue(_ cell: XNode, sharedStrings: [String]) -> CellValue {
        let raw = cell.child("v")?.text ?? ""
        switch cell.attributes["t"] {
        case "s":
            guard let i = Int(raw), sharedStrings.indices.contains(i) else { return .empty }
            return .text(sharedStrings[i])
        case "inlineStr":
            return cell.child("is").map { CellValue.text(text(ofStringItem: $0)) } ?? .empty
        case "str", "d":
            return raw.isEmpty ? .empty : .text(raw)
        case "b":
            return .bool(raw == "1")
        case "e":
            return .empty
        default:
            if raw.isEmpty { return .empty }
            return Double(raw).map { CellValue.number($0) } ?? .text(raw)
        }
    }

    /// "C12" -> 2
    static func columnIndex(fromReference ref: String) -> Int? {
        var index = 0
        var hasLetters = false
        for scalar in ref.unicodeScalars {
            guard scalar.properties.isAlphabetic, scalar.isASCII else { break }
            index = index * 26 + Int(scalar.value) - 64
            hasLetters = true
        }
        return hasLetters ? index - 1 : nil
    }
}

/// Liest CSV-Dateien (z. B. Bank-Exporte). Trennzeichen ; , oder Tab werden erkannt.
enum CSVReader {
    static func read(url: URL) throws -> [[CellValue]] {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1252)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw XLSXError.invalidFile
        }
        let text = content.hasPrefix("\u{FEFF}") ? String(content.dropFirst()) : content
        let firstLine = text.prefix { !$0.isNewline }
        let candidates: [Character] = [";", "\t", ","]
        let delimiter = candidates.max { a, b in
            firstLine.filter { $0 == a }.count < firstLine.filter { $0 == b }.count
        } ?? ";"

        var rows: [[CellValue]] = []
        var row: [CellValue] = []
        var field = ""
        var inQuotes = false

        func endField() {
            let trimmed = field.trimmingCharacters(in: .whitespaces)
            row.append(trimmed.isEmpty ? .empty : .text(trimmed))
            field = ""
        }
        func endRow() {
            endField()
            if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
            row = []
        }

        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if inQuotes {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == delimiter {
                endField()
            } else if ch.isNewline {
                endRow()
            } else {
                field.append(ch)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }
}
