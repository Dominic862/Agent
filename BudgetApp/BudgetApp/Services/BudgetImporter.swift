import Foundation

struct ParsedBooking {
    var date: Date
    var title: String
    var category: String
    var amount: Double
    var isIncome: Bool
    var note: String
}

struct ImportResult {
    var bookings: [ParsedBooking]
    var budgets: [(category: String, limit: Double)]
    var skippedRows: Int
    var sheetName: String

    var summary: String {
        var parts = ["\(bookings.count) Buchungen aus «\(sheetName)»"]
        if !budgets.isEmpty { parts.append("\(budgets.count) Budgets") }
        if skippedRows > 0 { parts.append("\(skippedRows) Zeilen übersprungen") }
        return parts.joined(separator: ", ")
    }
}

/// Erkennt in einer beliebigen Excel- oder CSV-Tabelle die Spalten für Datum, Betrag usw.
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
    private static let budgetKeys = ["monatsbudget", "budget", "limit", "betrag", "amount", "planbetrag", "plan"]
    private static let incomeCategoryHints = ["lohn", "gehalt", "salar", "einkommen", "salary", "income", "einnahme", "bonus"]

    static func importFile(at url: URL) throws -> ImportResult {
        let ext = url.pathExtension.lowercased()
        let sheets: [Worksheet] = (ext == "csv" || ext == "txt")
            ? [Worksheet(name: url.deletingPathExtension().lastPathComponent, rows: try CSVReader.read(url: url))]
            : try XLSXReader.read(url: url)
        guard sheets.contains(where: { !$0.rows.isEmpty }) else { throw XLSXError.noData }

        var best: (sheet: Worksheet, bookings: [ParsedBooking], skipped: Int)?
        var budgets: [(String, Double)] = []

        for sheet in sheets {
            if let parsed = parseTransactions(sheet), parsed.bookings.count > (best?.bookings.count ?? -1) {
                best = (sheet, parsed.bookings, parsed.skipped)
            } else if budgets.isEmpty, let parsedBudgets = parseBudgets(sheet) {
                budgets = parsedBudgets
            }
        }
        guard let best else { throw XLSXError.noTransactions }
        return ImportResult(bookings: best.bookings, budgets: budgets.map { (category: $0.0, limit: $0.1) },
                            skippedRows: best.skipped, sheetName: best.sheet.name)
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

    private static func parseBudgets(_ sheet: Worksheet) -> [(String, Double)]? {
        for (headerIndex, row) in sheet.rows.prefix(10).enumerated() {
            let headers = row.map { normalize($0.string) }
            guard column(headers, dateKeys) == nil,
                  let cat = column(headers, categoryKeys),
                  let limit = column(headers, budgetKeys), limit != cat else { continue }
            var result: [(String, Double)] = []
            for row in sheet.rows.dropFirst(headerIndex + 1) {
                guard row.indices.contains(cat), row.indices.contains(limit) else { continue }
                let name = row[cat].string
                guard !name.isEmpty, let value = parseAmount(row[limit]), value > 0 else { continue }
                result.append((name, value))
            }
            return result.isEmpty ? nil : result
        }
        return nil
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
