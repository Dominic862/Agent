import Foundation
import ZIPFoundation

/// Schreibt eine einfache, formatierte .xlsx-Datei (Kopfzeile fixiert, Datums- und Währungsformate).
enum XLSXWriter {
    enum Cell {
        case empty
        case header(String)
        case text(String)
        case number(Double)
        case money(Double)
        case percent(Double)
        case date(Date)
        case month(Date)
        case bold(String)
        /// Formel ohne führendes «=», mit vorberechnetem Wert für Vorschauen ohne Neuberechnung
        case formula(String, cached: Double, bold: Bool = false)
    }

    struct Sheet {
        var name: String
        var columnWidths: [Double]
        var rows: [[Cell]]
    }

    static func write(_ sheets: [Sheet], to url: URL) throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appending(path: UUID().uuidString + ".xlsx")
        defer { try? fm.removeItem(at: tmp) }

        let archive = try Archive(url: tmp, accessMode: .create)
        func add(_ path: String, _ xml: String) throws {
            let data = Data(xml.utf8)
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count),
                                 compressionMethod: .deflate) { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            }
        }

        try add("[Content_Types].xml", contentTypes(sheetCount: sheets.count))
        try add("_rels/.rels", rootRels)
        try add("xl/workbook.xml", workbook(sheets))
        try add("xl/_rels/workbook.xml.rels", workbookRels(sheetCount: sheets.count))
        try add("xl/styles.xml", styles)
        for (i, sheet) in sheets.enumerated() {
            try add("xl/worksheets/sheet\(i + 1).xml", worksheet(sheet))
        }

        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
        try fm.moveItem(at: tmp, to: url)
    }

    // MARK: - Teile

    private static let header = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"# + "\n"
    private static let mainNS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    private static let relNS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

    private static func contentTypes(sheetCount: Int) -> String {
        var s = header + #"<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">"#
        s += #"<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>"#
        s += #"<Default Extension="xml" ContentType="application/xml"/>"#
        s += #"<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>"#
        s += #"<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>"#
        for i in 1...max(sheetCount, 1) {
            s += #"<Override PartName="/xl/worksheets/sheet\#(i).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>"#
        }
        return s + "</Types>"
    }

    private static let rootRels = header + #"""
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\#
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\#
    </Relationships>
    """#

    private static func workbook(_ sheets: [Sheet]) -> String {
        var s = header + #"<workbook xmlns="\#(mainNS)" xmlns:r="\#(relNS)"><sheets>"#
        for (i, sheet) in sheets.enumerated() {
            s += #"<sheet name="\#(escape(String(sheet.name.prefix(31))))" sheetId="\#(i + 1)" r:id="rId\#(i + 1)"/>"#
        }
        return s + "</sheets></workbook>"
    }

    private static func workbookRels(sheetCount: Int) -> String {
        var s = header + #"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">"#
        for i in 1...max(sheetCount, 1) {
            s += #"<Relationship Id="rId\#(i)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\#(i).xml"/>"#
        }
        s += #"<Relationship Id="rId\#(sheetCount + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>"#
        return s + "</Relationships>"
    }

    /// Stil-Indizes: 0 Standard, 1 Kopfzeile, 2 Datum, 3 Währung, 4 Prozent, 5 Monat, 6 fett, 7 Währung fett
    private static let styles = header + #"""
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\#
    <numFmts count="4"><numFmt numFmtId="164" formatCode="dd.mm.yyyy"/><numFmt numFmtId="165" formatCode="#,##0.00"/>\#
    <numFmt numFmtId="166" formatCode="0.0%"/><numFmt numFmtId="167" formatCode="mmmm yyyy"/></numFmts>\#
    <fonts count="3"><font><sz val="11"/><name val="Calibri"/></font>\#
    <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>\#
    <font><b/><sz val="11"/><name val="Calibri"/></font></fonts>\#
    <fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>\#
    <fill><patternFill patternType="solid"><fgColor rgb="FF2F5597"/><bgColor indexed="64"/></patternFill></fill></fills>\#
    <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>\#
    <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>\#
    <cellXfs count="8">\#
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>\#
    <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>\#
    <xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>\#
    <xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>\#
    <xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>\#
    <xf numFmtId="167" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>\#
    <xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>\#
    <xf numFmtId="165" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>\#
    </cellXfs>\#
    <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>\#
    </styleSheet>
    """#

    private static func worksheet(_ sheet: Sheet) -> String {
        var s = header + #"<worksheet xmlns="\#(mainNS)" xmlns:r="\#(relNS)">"#
        s += #"<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>"#
        if !sheet.columnWidths.isEmpty {
            s += "<cols>"
            for (i, w) in sheet.columnWidths.enumerated() {
                s += #"<col min="\#(i + 1)" max="\#(i + 1)" width="\#(w)" customWidth="1"/>"#
            }
            s += "</cols>"
        }
        s += "<sheetData>"
        for (r, row) in sheet.rows.enumerated() {
            s += #"<row r="\#(r + 1)">"#
            for (c, cell) in row.enumerated() {
                s += xml(for: cell, ref: columnName(c) + String(r + 1))
            }
            s += "</row>"
        }
        return s + "</sheetData></worksheet>"
    }

    private static func xml(for cell: Cell, ref: String) -> String {
        func inline(_ text: String, style: Int) -> String {
            #"<c r="\#(ref)" t="inlineStr" s="\#(style)"><is><t xml:space="preserve">\#(escape(text))</t></is></c>"#
        }
        func number(_ value: Double, style: Int) -> String {
            guard value.isFinite else { return "" }
            return #"<c r="\#(ref)" s="\#(style)"><v>\#(value)</v></c>"#
        }
        switch cell {
        case .empty: return ""
        case .header(let t): return inline(t, style: 1)
        case .text(let t): return t.isEmpty ? "" : inline(t, style: 0)
        case .number(let v): return number(v, style: 0)
        case .money(let v): return number(v, style: 3)
        case .percent(let v): return number(v, style: 4)
        case .date(let d): return number(ExcelDate.serial(from: d), style: 2)
        case .month(let d): return number(ExcelDate.serial(from: d), style: 5)
        case .bold(let t): return inline(t, style: 6)
        case .formula(let f, let cached, let bold):
            let value = cached.isFinite ? "<v>\(cached)</v>" : ""
            return #"<c r="\#(ref)" s="\#(bold ? 7 : 3)"><f>\#(escape(f))</f>\#(value)</c>"#
        }
    }

    static func columnName(_ index: Int) -> String {
        var n = index + 1
        var name = ""
        while n > 0 {
            let r = (n - 1) % 26
            name = String(Character(Unicode.Scalar(UInt8(65 + r)))) + name
            n = (n - 1) / 26
        }
        return name
    }

    static func escape(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "\t", "\n", "\r": out.unicodeScalars.append(scalar)
            default:
                // In XML 1.0 unzulässige Steuerzeichen weglassen
                if scalar.value >= 0x20 { out.unicodeScalars.append(scalar) }
            }
        }
        return out
    }
}

/// Umrechnung Excel-Seriennummer <-> Datum (Basis 30.12.1899, lokales Kalenderdatum).
enum ExcelDate {
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private static let base = utc.date(from: DateComponents(year: 1899, month: 12, day: 30))!

    static func serial(from date: Date) -> Double {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let utcDay = utc.date(from: parts) else { return 0 }
        return (utcDay.timeIntervalSince(base) / 86_400).rounded()
    }

    static func date(fromSerial serial: Double) -> Date? {
        guard serial > 0, serial < 2_958_466 else { return nil }
        let utcDate = base.addingTimeInterval(serial.rounded(.down) * 86_400)
        let parts = utc.dateComponents([.year, .month, .day], from: utcDate)
        return Calendar.current.date(from: parts)
    }
}
