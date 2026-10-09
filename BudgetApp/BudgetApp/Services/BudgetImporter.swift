import Foundation

struct ParsedBooking {
    var date: Date
    var title: String
    var category: String
    var amount: Double
    var isIncome: Bool
    var note: String
}

struct ParsedPlan {
    var name: String
    var year: Int
    var items: [ParsedPlanItem]
}

struct ParsedPlanItem {
    var title: String
    var category: String
    var isIncome: Bool
    var amounts: [Double]
}

struct ImportResult {
    var plans: [ParsedPlan]
    var bookings: [ParsedBooking]
    var skippedRows: Int
    var notes: [String]

    var summary: String {
        var parts: [String] = []
        if !plans.isEmpty {
            parts.append("\(plans.count) Jahrespläne (\(plans.map(\.name).joined(separator: ", ")))")
        }
        if !bookings.isEmpty { parts.append("\(bookings.count) Buchungen") }
        if skippedRows > 0 { parts.append("\(skippedRows) Zeilen übersprungen") }
        return parts.joined(separator: ", ")
    }
}

/// Liest zwei Excel-Formate:
/// 1. Jahresplan: Posten als Zeilen, Monate (Januar–Dezember) als Spalten, darunter Total, Einnahmen und Überschuss.
/// 2. Buchungsliste: Spalten wie Datum, Beschreibung, Kategorie, Typ, Betrag (auch Bank-Exporte als CSV).
enum BudgetImporter {
    private static let dateKeys = ["datum", "date", "tag", "buchungsdatum", "valuta", "valutadatum"]
    private static let titleKeys = ["beschreibung", "description", "titel", "title", "text", "buchungstext",
                                    "verwendungszweck", "empfanger", "name", "zweck", "details", "posten"]
    private static let categoryKeys = ["kategorie", "category", "rubrik", "gruppe"]
    private static let typeKeys = ["typ", "type", "art", "einnahmeausgabe"]
    private static let amountKeys = ["betrag", "amount", "summe", "chf", "eur", "usd", "preis"]
    private static let incomeKeys = ["einnahme", "einnahmen", "income", "gutschrift", "haben", "credit", "eingang"]
    private static let expenseKeys = ["ausgabe", "ausgaben", "expense", "expenses", "belastung", "soll", "debit", "lastschrift"]
    private static let noteKeys = ["notiz", "note", "notes", "bemerkung", "kommentar", "comment"]
    private static let incomeCategoryHints = ["lohn", "gehalt", "salar", "einkommen", "salary", "income", "einnahme", "bonus"]

    static func importFile(at url: URL) throws -> ImportResult {
        let ext = url.pathExtension.lowercased()
        let sheets: [Worksheet] = (ext == "csv" || ext == "txt")
            ? [Worksheet(name: url.deletingPathExtension().lastPathComponent, rows: try CSVReader.read(url: url))]
            : try XLSXReader.read(url: url)
        guard sheets.contains(where: { !$0.rows.isEmpty }) else { throw XLSXError.noData }

        var result = ImportResult(plans: [], bookings: [], skippedRows: 0, notes: [])
        for sheet in sheets {
            if let plan = parsePlan(sheet, notes: &result.notes) {
                result.plans.append(plan)
            } else if let parsed = parseTransactions(sheet) {
                result.bookings += parsed.bookings
                result.skippedRows += parsed.skipped
            }
        }
        guard !result.plans.isEmpty || !result.bookings.isEmpty else { throw XLSXError.noTransactions }
        return result
    }

    // MARK: - Jahresplan

    private static let monthKeys = ["januar", "februar", "marz", "april", "mai", "juni",
                                    "juli", "august", "september", "oktober", "november", "dezember"]
    private static let englishMonthKeys = ["january", "february", "march", "april", "may", "june",
                                           "july", "august", "september", "october", "november", "december"]

    /// "Januar", "Jan", "Jan." oder "January" → 0
    static func monthIndex(_ text: String) -> Int? {
        let n = normalize(text)
        guard n.count >= 3, n.allSatisfy(\.isLetter) else { return nil }
        for keys in [monthKeys, englishMonthKeys] {
            if let i = keys.firstIndex(of: n) { return i }
        }
        for keys in [monthKeys, englishMonthKeys] {
            if let i = keys.firstIndex(where: { $0.hasPrefix(n) }) { return i }
        }
        if n == "mrz" || n == "maerz" { return 2 }
        return nil
    }

    private static func monthColumns(_ row: [CellValue]) -> [Int: Int] {
        var columns: [Int: Int] = [:]
        for (column, cell) in row.enumerated() {
            guard case .text(let text) = cell, let month = monthIndex(text), columns[month] == nil else { continue }
            columns[month] = column
        }
        return columns
    }

    private static func parsePlan(_ sheet: Worksheet, notes: inout [String]) -> ParsedPlan? {
        guard let headerIndex = sheet.rows.prefix(30).firstIndex(where: { monthColumns($0).count == 12 }) else { return nil }
        let header = sheet.rows[headerIndex]
        let columnsByMonth = monthColumns(header)
        let months = (0..<12).compactMap { columnsByMonth[$0] }
        let firstMonth = months.min() ?? 0
        let categoryColumn = header.prefix(firstMonth).firstIndex { normalize($0.string).hasPrefix("kategorie") }

        func label(_ row: [CellValue]) -> String {
            for column in 0..<min(firstMonth, row.count) where column != categoryColumn {
                if case .text(let t) = row[column], !t.trimmingCharacters(in: .whitespaces).isEmpty {
                    return t.trimmingCharacters(in: .whitespaces)
                }
            }
            return ""
        }
        func values(_ row: [CellValue]) -> [Double] {
            months.map { column in
                guard row.indices.contains(column), case .number(let n) = row[column] else { return 0 }
                return n
            }
        }
        func hasMonthNames(_ row: [CellValue]) -> Bool { monthColumns(row).count >= 6 }

        var items: [ParsedPlanItem] = []
        var inIncome = false
        var sheetTotals: [Double]?
        for row in sheet.rows.dropFirst(headerIndex + 1) {
            if hasMonthNames(row) {
                if inIncome { break }      // nächster Block (z. B. Ist-Erfassung) beginnt
                inIncome = true
                continue
            }
            let title = label(row)
            let v = values(row)
            let key = normalize(title)
            if title.isEmpty {
                if v.contains(where: { $0 != 0 }) {
                    if !inIncome {
                        inIncome = true
                        sheetTotals = v
                    } else if sheetTotals == nil {
                        sheetTotals = v
                    }
                }
                continue
            }
            if key.hasPrefix("uberschuss") || key.hasPrefix("saldo") || key.hasPrefix("differenz") { break }
            if key.hasPrefix("total") || key.hasPrefix("summe") {
                if !inIncome { inIncome = true; sheetTotals = v }
                continue
            }
            // Überschriften ohne Beträge und Hilfszeilen wie «Rückstellungen pro Monat …» überspringen
            if key.contains("promonat") || !v.contains(where: { $0 != 0 }) { continue }

            var category = ""
            if let c = categoryColumn, row.indices.contains(c) { category = row[c].string }
            if category.isEmpty { category = CategoryStyle.autoCategory(for: title, isIncome: inIncome) }
            items.append(ParsedPlanItem(title: title, category: category, isIncome: inIncome, amounts: v))
        }

        let expenses = items.filter { !$0.isIncome }
        guard expenses.count >= 2 else { return nil }

        // Abgleich mit der Total-Zeile im Excel: Ist ein Posten dort nicht mitgezählt, wird er weggelassen.
        if let totals = sheetTotals {
            let ours = (0..<12).map { m in expenses.reduce(0) { $0 + $1.amounts[m] } }
            let checked = (0..<12).filter { totals[$0] != 0 }
            let diff = checked.map { ours[$0] - totals[$0] }
            if diff.contains(where: { abs($0) > 0.05 }) {
                if let excluded = items.firstIndex(where: { item in
                    !item.isIncome && zip(checked, diff).allSatisfy { pair in abs(item.amounts[pair.0] - pair.1) < 0.05 }
                }) {
                    notes.append("«\(sheet.name)»: «\(items[excluded].title)» ist in der Excel-Summe nicht enthalten und wurde weggelassen.")
                    items.remove(at: excluded)
                } else if let maxDiff = diff.map(abs).max() {
                    notes.append("«\(sheet.name)»: Die Summe weicht um bis zu \(String(format: "%.2f", maxDiff)) von der Total-Zeile im Excel ab.")
                }
            }
        }
        if !items.contains(where: \.isIncome) {
            notes.append("«\(sheet.name)»: Keine Einnahmen gefunden – ergänze sie in der App.")
        }

        return ParsedPlan(name: sheet.name, year: year(in: sheet.name) ?? year(inHeader: header, before: firstMonth) ?? 0,
                          items: items)
    }

    /// "2026 (2)" → 2026
    static func year(in text: String) -> Int? {
        var digits = ""
        for ch in text + " " {
            if ch.isNumber { digits.append(ch); continue }
            if digits.count == 4, let y = Int(digits), (2000...2100).contains(y) { return y }
            digits = ""
        }
        return nil
    }

    private static func year(inHeader header: [CellValue], before column: Int) -> Int? {
        for cell in header.prefix(column) {
            if case .number(let n) = cell, (2000...2100).contains(Int(n)) { return Int(n) }
            if case .text(let t) = cell, let y = year(in: t) { return y }
        }
        return nil
    }

    // MARK: - Tabellen

    private struct Columns {
        var date: Int
        var title: Int?
        var category: Int?
        var type: Int?
        var amount: Int?
        var income: Int?
        var expense: Int?
        var note: Int?
    }

    private static func parseTransactions(_ sheet: Worksheet) -> (bookings: [ParsedBooking], skipped: Int)? {
        for (headerIndex, row) in sheet.rows.prefix(25).enumerated() {
            let headers = row.map { normalize($0.string) }
            guard let date = column(headers, dateKeys) else { continue }
            var cols = Columns(date: date,
                               title: column(headers, titleKeys),
                               category: column(headers, categoryKeys),
                               type: column(headers, typeKeys),
                               amount: column(headers, amountKeys),
                               income: column(headers, incomeKeys),
                               expense: column(headers, expenseKeys),
                               note: column(headers, noteKeys))
            // Eine Spalte «Einnahme/Ausgabe» ist ein Typ, kein Betrag
            if cols.type == nil, let i = cols.income, i == cols.expense { cols.type = i }
            if let t = cols.type {
                if cols.income == t { cols.income = nil }
                if cols.expense == t { cols.expense = nil }
            }
            guard cols.amount != nil || cols.income != nil || cols.expense != nil else { continue }
            return parseRows(sheet.rows.dropFirst(headerIndex + 1), cols)
        }
        return nil
    }

    private static func parseRows(_ rows: ArraySlice<[CellValue]>, _ cols: Columns) -> (bookings: [ParsedBooking], skipped: Int) {
        func cell(_ row: [CellValue], _ index: Int?) -> CellValue {
            guard let index, row.indices.contains(index) else { return .empty }
            return row[index]
        }

        struct Raw { var date: Date; var title: String; var category: String; var signed: Double; var typeIncome: Bool?; var note: String }
        var raws: [Raw] = []
        var skipped = 0

        for row in rows where row.contains(where: { !$0.isEmpty }) {
            guard let date = parseDate(cell(row, cols.date)) else { skipped += 1; continue }
            var signed: Double?
            if let a = parseAmount(cell(row, cols.amount)), a != 0 {
                signed = a
            } else if let i = parseAmount(cell(row, cols.income)), i != 0 {
                signed = abs(i)
            } else if let e = parseAmount(cell(row, cols.expense)), e != 0 {
                signed = -abs(e)
            }
            guard let signed else { skipped += 1; continue }

            var typeIncome: Bool?
            let typeText = normalize(cell(row, cols.type).string)
            if !typeText.isEmpty {
                typeIncome = incomeKeys.contains { typeText.hasPrefix($0) } || typeText.hasPrefix("lohn") || typeText == "plus" || typeText == "in"
            } else if cols.amount == nil {
                typeIncome = signed > 0
            }
            let category = cell(row, cols.category).string
            let title = cell(row, cols.title).string
            raws.append(Raw(date: date, title: title, category: category, signed: signed,
                            typeIncome: typeIncome, note: cell(row, cols.note).string))
        }

        // Ohne Typ-Spalte: Enthält die Datei negative Beträge, gilt + als Einnahme (Bank-Export).
        // Sonst sind alle Beträge Ausgaben, ausser die Kategorie deutet auf Einkommen hin.
        let hasNegatives = raws.contains { $0.signed < 0 }
        let bookings = raws.map { raw -> ParsedBooking in
            let isIncome: Bool
            if let t = raw.typeIncome {
                isIncome = t
            } else if hasNegatives {
                isIncome = raw.signed > 0
            } else {
                let c = normalize(raw.category)
                isIncome = incomeCategoryHints.contains { c.contains($0) }
            }
            let category = raw.category.isEmpty ? (isIncome ? "Sonstige Einnahmen" : "Sonstiges") : raw.category
            return ParsedBooking(date: raw.date,
                                 title: raw.title.isEmpty ? category : raw.title,
                                 category: category,
                                 amount: abs(raw.signed),
                                 isIncome: isIncome,
                                 note: raw.note)
        }
        return (bookings, skipped)
    }

    // MARK: - Werte

    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_CH"))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    /// Exakter Treffer zuerst, danach Spalten, die mit einem Schlüssel beginnen.
    private static func column(_ headers: [String], _ keys: [String]) -> Int? {
        for key in keys {
            if let i = headers.firstIndex(of: key) { return i }
        }
        for key in keys where key.count >= 4 {
            if let i = headers.firstIndex(where: { $0.hasPrefix(key) }) { return i }
        }
        return nil
    }

    private static let dateFormatters: [DateFormatter] = [
        "dd.MM.yyyy", "d.M.yyyy", "dd.MM.yy", "d.M.yy", "yyyy-MM-dd", "dd/MM/yyyy", "d/M/yyyy",
        "MM/dd/yyyy", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "dd.MM.yyyy HH:mm", "dd-MM-yyyy"
    ].map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        f.isLenient = false
        return f
    }

    static func parseDate(_ value: CellValue) -> Date? {
        switch value {
        case .number(let n):
            return ExcelDate.date(fromSerial: n)
        case .text(let raw):
            let s = raw.trimmingCharacters(in: .whitespaces)
            for f in dateFormatters {
                if let d = f.date(from: s) { return Calendar.current.startOfDay(for: d) }
            }
            if let n = Double(s), n > 20_000, n < 80_000 { return ExcelDate.date(fromSerial: n) }
            return nil
        default:
            return nil
        }
    }

    static func parseAmount(_ value: CellValue) -> Double? {
        switch value {
        case .number(let n): return n
        case .text(let s): return parseAmount(s)
        default: return nil
        }
    }

    /// Versteht u. a. "1'234.50", "1.234,50", "-12,00", "CHF 12.–", "(45.00)", "12.50-".
    static func parseAmount(_ text: String) -> Double? {
        var s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        var negative = false
        if s.hasPrefix("(") && s.hasSuffix(")") { negative = true }
        if s.hasSuffix("-") && s.count > 1 { negative = true; s.removeLast() }
        s = s.replacingOccurrences(of: ".–", with: "").replacingOccurrences(of: ".-", with: "")
        s = String(s.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" || $0 == "−" })
        if s.hasPrefix("-") || s.hasPrefix("−") { negative = true }
        s = s.filter { $0 != "-" && $0 != "−" }
        guard !s.isEmpty else { return nil }

        let lastComma = s.lastIndex(of: ",")
        let lastDot = s.lastIndex(of: ".")
        if let c = lastComma, let d = lastDot {
            if c > d {
                s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                s = s.replacingOccurrences(of: ",", with: "")
            }
        } else if let c = lastComma {
            let decimals = s.distance(from: c, to: s.endIndex) - 1
            let commas = s.filter { $0 == "," }.count
            s = (commas == 1 && decimals <= 2)
                ? s.replacingOccurrences(of: ",", with: ".")
                : s.replacingOccurrences(of: ",", with: "")
        } else if s.filter({ $0 == "." }).count > 1 {
            s = s.replacingOccurrences(of: ".", with: "")
        }
        guard let value = Double(s) else { return nil }
        return negative ? -value : value
    }
}
