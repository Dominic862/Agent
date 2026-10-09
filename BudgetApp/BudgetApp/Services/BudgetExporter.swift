import Foundation
import SwiftData

/// Baut die Excel-Arbeitsmappe: Transaktionen, Budgets und eine Monatsübersicht.
/// Transaktionen und Budgets lassen sich wieder importieren.
enum BudgetExporter {
    static func write(bookings: [Booking], budgets: [CategoryBudget], to url: URL) throws {
        try XLSXWriter.write(sheets(bookings: bookings, budgets: budgets), to: url)
    }

    static func temporaryFile(bookings: [Booking], budgets: [CategoryBudget], name: String? = nil) throws -> URL {
        let fileName = name ?? "Budget \(Date().formatted(.iso8601.year().month().day())).xlsx"
        let url = FileManager.default.temporaryDirectory.appending(path: fileName)
        try write(bookings: bookings, budgets: budgets, to: url)
        return url
    }

    static func sheets(bookings: [Booking], budgets: [CategoryBudget]) -> [XLSXWriter.Sheet] {
        let sorted = bookings.sorted { $0.date < $1.date }

        var transactions: [[XLSXWriter.Cell]] = [
            ["Datum", "Beschreibung", "Kategorie", "Typ", "Betrag", "Notiz"].map { XLSXWriter.Cell.header($0) }
        ]
        for b in sorted {
            transactions.append([.date(b.date), .text(b.title), .text(b.category),
                                 .text(b.isIncome ? "Einnahme" : "Ausgabe"), .money(b.amount), .text(b.note)])
        }

        var budgetRows: [[XLSXWriter.Cell]] = [[.header("Kategorie"), .header("Monatsbudget")]]
        for b in budgets.sorted(by: { $0.category < $1.category }) {
            budgetRows.append([.text(b.category), .money(b.monthlyLimit)])
        }

        var overview: [[XLSXWriter.Cell]] = [
            ["Monat", "Einnahmen", "Ausgaben", "Saldo", "Sparquote"].map { XLSXWriter.Cell.header($0) }
        ]
        if let first = sorted.first?.date.startOfMonth, let last = sorted.last?.date.startOfMonth {
            var month = first
            while month <= last {
                let s = Analytics.summary(bookings, month: month)
                overview.append([.month(month), .money(s.income), .money(s.expenses), .money(s.balance),
                                 s.savingsRate.map { XLSXWriter.Cell.percent($0) } ?? XLSXWriter.Cell.empty])
                month = month.addingMonths(1)
            }
        }

        return [
            .init(name: "Transaktionen", columnWidths: [12, 34, 18, 12, 14, 30], rows: transactions),
            .init(name: "Budgets", columnWidths: [22, 16], rows: budgetRows),
            .init(name: "Übersicht", columnWidths: [18, 14, 14, 14, 12], rows: overview),
        ]
    }
}

/// Legt beim Wechsel in den Hintergrund eine aktuelle Budget.xlsx im Dokumente-Ordner ab
/// (sichtbar in der «Dateien»-App unter «Auf meinem iPhone › Budget»).
enum AutoSave {
    static var fileURL: URL { URL.documentsDirectory.appending(path: "Budget.xlsx") }

    @MainActor
    static func run(context: ModelContext) {
        do {
            let bookings = try context.fetch(FetchDescriptor<Booking>())
            let budgets = try context.fetch(FetchDescriptor<CategoryBudget>())
            guard !bookings.isEmpty || !budgets.isEmpty else { return }
            try BudgetExporter.write(bookings: bookings, budgets: budgets, to: fileURL)
        } catch {
            print("Auto-Save fehlgeschlagen: \(error)")
        }
    }
}
