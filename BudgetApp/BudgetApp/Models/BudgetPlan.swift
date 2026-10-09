import Foundation
import SwiftData

/// Ein Jahresbudget (Soll) wie ein Tabellenblatt im Excel: Posten als Zeilen, Monate als Spalten.
@Model
final class BudgetPlan {
    var name: String = ""
    /// 0 = Jahr unbekannt (z. B. ein Blatt, das nach einem Ort benannt ist)
    var year: Int = 0
    var sortOrder: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \PlanItem.plan)
    var items: [PlanItem] = []

    init(name: String, year: Int, sortOrder: Int = 0) {
        self.name = name
        self.year = year
        self.sortOrder = sortOrder
    }

    var expenseItems: [PlanItem] { items.filter { !$0.isIncome }.sorted { $0.sortOrder < $1.sortOrder } }
    var incomeItems: [PlanItem] { items.filter(\.isIncome).sorted { $0.sortOrder < $1.sortOrder } }

    func expenses(month: Int) -> Double { expenseItems.reduce(0) { $0 + $1.amount(month: month) } }
    func income(month: Int) -> Double { incomeItems.reduce(0) { $0 + $1.amount(month: month) } }
    func surplus(month: Int) -> Double { income(month: month) - expenses(month: month) }

    var yearlyExpenses: Double { (0..<12).reduce(0) { $0 + expenses(month: $1) } }
    var yearlyIncome: Double { (0..<12).reduce(0) { $0 + income(month: $1) } }

    /// Ausgaben pro Kategorie für einen Monat (0–11) oder – mit `nil` – fürs ganze Jahr.
    func expensesByCategory(month: Int?) -> [CategoryTotal] {
        var totals: [String: Double] = [:]
        for item in expenseItems {
            totals[item.category, default: 0] += month.map { item.amount(month: $0) } ?? item.yearly
        }
        return totals.filter { $0.value > 0.004 }
            .map { CategoryTotal(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    var title: String { year > 0 && !name.contains(String(year)) ? "\(name) (\(year))" : name }
    var nextSortOrder: Int { (items.map(\.sortOrder).max() ?? -1) + 1 }
}

@Model
final class PlanItem {
    var title: String = ""
    var category: String = "Sonstiges"
    var isIncome: Bool = false
    /// Zwölf Monatsbeträge, Januar bis Dezember
    var amounts: [Double] = []
    var sortOrder: Int = 0
    var plan: BudgetPlan?

    init(title: String, category: String, isIncome: Bool, amounts: [Double], sortOrder: Int) {
        self.title = title
        self.category = category
        self.isIncome = isIncome
        self.amounts = PlanItem.normalized(amounts)
        self.sortOrder = sortOrder
    }

    func amount(month: Int) -> Double { amounts.indices.contains(month) ? amounts[month] : 0 }
    var yearly: Double { amounts.reduce(0, +) }

    static func normalized(_ values: [Double]) -> [Double] {
        Array((values + Array(repeating: 0, count: 12)).prefix(12))
    }
}

extension Date {
    /// Monat als Index 0–11
    var monthIndex: Int { Calendar.current.component(.month, from: self) - 1 }
    var year: Int { Calendar.current.component(.year, from: self) }
}

enum PlanSelection {
    static let monthNames = Calendar.current.standaloneMonthSymbols
    static let shortMonthNames = Calendar.current.shortStandaloneMonthSymbols

    /// Plan für das Jahr von `month`; bevorzugt den zuletzt gewählten Plan (z. B. «2026 (2)»).
    static func plan(for month: Date, in plans: [BudgetPlan], preferred: String) -> BudgetPlan? {
        let candidates = plans.filter { $0.year == month.year }.sorted { $0.sortOrder < $1.sortOrder }
        return candidates.first { $0.name == preferred } ?? candidates.first
    }

    static func previousPlan(before plan: BudgetPlan, in plans: [BudgetPlan]) -> BudgetPlan? {
        guard plan.year > 0 else { return nil }
        return plans.filter { $0.year == plan.year - 1 }.sorted { $0.sortOrder < $1.sortOrder }.first
    }
}
