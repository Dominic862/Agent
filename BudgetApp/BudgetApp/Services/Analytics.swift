import Foundation

struct MonthSummary: Identifiable {
    let month: Date
    let income: Double
    let expenses: Double

    var id: Date { month }
    var balance: Double { income - expenses }
    var savingsRate: Double? { income > 0 ? balance / income : nil }
}

struct CategoryTotal: Identifiable {
    let category: String
    let amount: Double
    var id: String { category }
}

struct RecurringPayment: Identifiable {
    let title: String
    let category: String
    let monthlyAmount: Double
    let months: Int
    var id: String { title }
}

enum Analytics {
    static func inMonth(_ bookings: [Booking], _ month: Date) -> [Booking] {
        let start = month.startOfMonth
        let end = start.addingMonths(1)
        return bookings.filter { $0.date >= start && $0.date < end }
    }

    static func summary(_ bookings: [Booking], month: Date) -> MonthSummary {
        let items = inMonth(bookings, month)
        var income = 0.0, expenses = 0.0
        for b in items {
            if b.isIncome { income += b.amount } else { expenses += b.amount }
        }
        return MonthSummary(month: month.startOfMonth, income: income, expenses: expenses)
    }

    static func expensesByCategory(_ items: [Booking]) -> [CategoryTotal] {
        var totals: [String: Double] = [:]
        for b in items where !b.isIncome { totals[b.category, default: 0] += b.amount }
        return totals.map { CategoryTotal(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    static func trend(_ bookings: [Booking], endingAt month: Date, count: Int = 6) -> [MonthSummary] {
        (0..<count).reversed().map { summary(bookings, month: month.startOfMonth.addingMonths(-$0)) }
    }

    /// Durchschnittliche Ausgaben pro Kategorie in den Monaten vor `month`.
    /// Gemittelt wird nur über Monate mit Ausgaben, damit Monate vor dem ersten Eintrag nicht verwässern.
    static func averageExpensesByCategory(_ bookings: [Booking], before month: Date, months: Int = 3) -> [String: Double] {
        var totals: [String: Double] = [:]
        var activeMonths = 0
        for offset in 1...months {
            let items = inMonth(bookings, month.startOfMonth.addingMonths(-offset)).filter { !$0.isIncome }
            guard !items.isEmpty else { continue }
            activeMonths += 1
            for b in items { totals[b.category, default: 0] += b.amount }
        }
        guard activeMonths > 0 else { return [:] }
        return totals.mapValues { $0 / Double(activeMonths) }
    }

    /// Budgetvorschlag: Durchschnitt der letzten drei Monate, auf 10 aufgerundet.
    static func suggestedBudgets(_ bookings: [Booking], month: Date) -> [String: Double] {
        var base = averageExpensesByCategory(bookings, before: month)
        if base.isEmpty {
            base = Dictionary(uniqueKeysWithValues: expensesByCategory(inMonth(bookings, month)).map { ($0.category, $0.amount) })
        }
        return base.filter { $0.value >= 10 }.mapValues { ($0 / 10).rounded(.up) * 10 }
    }

    /// Ausgaben, die in mindestens drei Monaten mit ähnlichem Betrag (±15 %) auftauchen – typisch für Abos.
    static func recurringPayments(_ bookings: [Booking], endingAt month: Date, lookback: Int = 6) -> [RecurringPayment] {
        let start = month.startOfMonth.addingMonths(-(lookback - 1))
        let end = month.startOfMonth.addingMonths(1)
        let relevant = bookings.filter { !$0.isIncome && $0.date >= start && $0.date < end }
        let groups = Dictionary(grouping: relevant) { normalizedTitle($0.title) }

        var result: [RecurringPayment] = []
        for (key, items) in groups where !key.isEmpty {
            let months = Set(items.map { $0.date.startOfMonth })
            guard months.count >= 3, items.count <= months.count + 1 else { continue }
            let amounts = items.map(\.amount)
            guard let low = amounts.min(), let high = amounts.max(), low > 0, high / low <= 1.15 else { continue }
            let average = amounts.reduce(0, +) / Double(amounts.count)
            result.append(RecurringPayment(title: items[0].title, category: items[0].category,
                                           monthlyAmount: average, months: months.count))
        }
        return result.sorted { $0.monthlyAmount > $1.monthlyAmount }
    }

    private static func normalizedTitle(_ title: String) -> String {
        title.lowercased()
            .filter { !$0.isNumber }
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .joined(separator: " ")
    }
}
