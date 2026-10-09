import Foundation
import SwiftData

/// Baut die Excel-Arbeitsmappe im Format des Budget-Excels:
/// ein Blatt pro Jahresplan (Posten × Monate mit Summenformeln, Einnahmen, Überschuss)
/// sowie – falls vorhanden – ein Blatt «Transaktionen» mit den Ist-Buchungen.
/// Die Datei lässt sich wieder importieren.
enum BudgetExporter {
    static func write(plans: [BudgetPlan], bookings: [Booking], to url: URL) throws {
        try XLSXWriter.write(sheets(plans: plans, bookings: bookings), to: url)
    }

    static func temporaryFile(plans: [BudgetPlan], bookings: [Booking], name: String? = nil) throws -> URL {
        let fileName = name ?? "Budget \(Date().formatted(.iso8601.year().month().day())).xlsx"
        let url = FileManager.default.temporaryDirectory.appending(path: fileName)
        try write(plans: plans, bookings: bookings, to: url)
        return url
    }

    static func sheets(plans: [BudgetPlan], bookings: [Booking]) -> [XLSXWriter.Sheet] {
        var sheets: [XLSXWriter.Sheet] = []
        var usedNames = Set<String>()
        for plan in plans.sorted(by: { ($0.sortOrder, $0.year) < ($1.sortOrder, $1.year) }) {
            sheets.append(planSheet(plan, name: uniqueSheetName(plan.name, used: &usedNames)))
        }
        if !bookings.isEmpty {
            sheets.append(transactionSheet(bookings, name: uniqueSheetName("Transaktionen", used: &usedNames)))
        }
        if sheets.isEmpty {
            sheets.append(planSheet(BudgetPlan(name: String(Date().year), year: Date().year), name: String(Date().year)))
        }
        return sheets
    }

    // MARK: - Jahresplan

    private static func planSheet(_ plan: BudgetPlan, name: String) -> XLSXWriter.Sheet {
        let col = XLSXWriter.columnName
        let firstMonth = 3   // Spalte D
        let yearColumn = col(firstMonth + 12)   // Spalte P

        var rows: [[XLSXWriter.Cell]] = []
        var header: [XLSXWriter.Cell] = [
            plan.year > 0 && !name.contains(String(plan.year)) ? .number(Double(plan.year)) : .empty,
            .header("Budget"), .header("Kategorie"),
        ]
        header += PlanSelection.monthNames.map { XLSXWriter.Cell.header($0) }
        header.append(.header("pro Jahr"))
        rows.append(header)

        func itemRow(_ item: PlanItem) -> [XLSXWriter.Cell] {
            let r = rows.count + 1
            var row: [XLSXWriter.Cell] = [.empty, .text(item.title), .text(item.category)]
            row += item.amounts.map { XLSXWriter.Cell.money($0) }
            row.append(.formula("SUM(\(col(firstMonth))\(r):\(col(firstMonth + 11))\(r))", cached: item.yearly))
            return row
        }
        func totalRow(_ title: String, from: Int, to: Int, values: [Double]) -> [XLSXWriter.Cell] {
            let r = rows.count + 1
            var row: [XLSXWriter.Cell] = [.empty, .bold(title), .empty]
            for m in 0..<12 {
                let c = col(firstMonth + m)
                row.append(to >= from
                           ? .formula("SUM(\(c)\(from):\(c)\(to))", cached: values[m], bold: true)
                           : .formula("0", cached: 0, bold: true))
            }
            row.append(.formula("SUM(\(col(firstMonth))\(r):\(col(firstMonth + 11))\(r))",
                                cached: values.reduce(0, +), bold: true))
            return row
        }

        let expenseStart = rows.count + 1
        for item in plan.expenseItems { rows.append(itemRow(item)) }
        let expenseEnd = rows.count
        let expenseTotalRow = rows.count + 1
        rows.append(totalRow("Total Ausgaben", from: expenseStart, to: expenseEnd,
                             values: (0..<12).map { plan.expenses(month: $0) }))
        rows.append([])

        let incomeStart = rows.count + 1
        for item in plan.incomeItems { rows.append(itemRow(item)) }
        let incomeEnd = rows.count
        let incomeTotalRow = rows.count + 1
        rows.append(totalRow("Total Einnahmen", from: incomeStart, to: incomeEnd,
                             values: (0..<12).map { plan.income(month: $0) }))

        var surplus: [XLSXWriter.Cell] = [.empty, .bold("Überschuss/Negativ?"), .empty]
        for m in 0..<12 {
            let c = col(firstMonth + m)
            surplus.append(.formula("\(c)\(incomeTotalRow)-\(c)\(expenseTotalRow)", cached: plan.surplus(month: m), bold: true))
        }
        surplus.append(.formula("\(yearColumn)\(incomeTotalRow)-\(yearColumn)\(expenseTotalRow)",
                                cached: plan.yearlyIncome - plan.yearlyExpenses, bold: true))
        rows.append(surplus)

        return .init(name: name, columnWidths: [6, 42, 22] + Array(repeating: 12, count: 12) + [14], rows: rows)
    }

    // MARK: - Ist-Buchungen

    private static func transactionSheet(_ bookings: [Booking], name: String) -> XLSXWriter.Sheet {
        var rows: [[XLSXWriter.Cell]] = [
            ["Datum", "Beschreibung", "Kategorie", "Typ", "Betrag", "Notiz"].map { XLSXWriter.Cell.header($0) }
        ]
        for b in bookings.sorted(by: { $0.date < $1.date }) {
            rows.append([.date(b.date), .text(b.title), .text(b.category),
                         .text(b.isIncome ? "Einnahme" : "Ausgabe"), .money(b.amount), .text(b.note)])
        }
        return .init(name: name, columnWidths: [12, 34, 22, 12, 14, 30], rows: rows)
    }

    /// Blattnamen: max. 31 Zeichen, ohne : \ / ? * [ ], eindeutig
    private static func uniqueSheetName(_ raw: String, used: inout Set<String>) -> String {
        let forbidden: Set<Character> = [":", "\\", "/", "?", "*", "[", "]"]
        var base = String(raw.filter { !forbidden.contains($0) }.prefix(31)).trimmingCharacters(in: .whitespaces)
        if base.isEmpty { base = "Plan" }
        var name = base
        var n = 2
        while used.contains(name.lowercased()) {
            let suffix = " (\(n))"
            name = String(base.prefix(31 - suffix.count)) + suffix
            n += 1
        }
        used.insert(name.lowercased())
        return name
    }
}

/// Legt beim Wechsel in den Hintergrund eine aktuelle Budget.xlsx im Dokumente-Ordner ab
/// (sichtbar in der «Dateien»-App unter «Auf meinem iPhone › Budget»).
enum AutoSave {
    static var fileURL: URL { URL.documentsDirectory.appending(path: "Budget.xlsx") }

    @MainActor
    static func run(context: ModelContext) {
        do {
            let plans = try context.fetch(FetchDescriptor<BudgetPlan>())
            let bookings = try context.fetch(FetchDescriptor<Booking>())
            guard !plans.isEmpty || !bookings.isEmpty else { return }
            try BudgetExporter.write(plans: plans, bookings: bookings, to: fileURL)
        } catch {
            print("Auto-Save fehlgeschlagen: \(error)")
        }
    }
}
