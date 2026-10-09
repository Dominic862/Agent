import Foundation
import SwiftData

/// Beispieldaten: ein Jahresplan fürs aktuelle Jahr und Buchungen der letzten drei Monate.
enum SampleData {
    private struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    @MainActor
    @discardableResult
    static func insertPlan(into context: ModelContext, year: Int, name: String? = nil) -> BudgetPlan {
        let plan = BudgetPlan(name: name ?? String(year), year: year)
        context.insert(plan)
        let items: [(String, Bool, Double)] = [
            ("Wohnungsmiete", false, 1950), ("Strom", false, 85), ("Hausrat / Haftpflichtversicherung", false, 1126.0 / 12),
            ("Krankenkasse", false, 520), ("Autoversicherung", false, 1100.0 / 12), ("Benzin", false, 150),
            ("ÖV-Abo", false, 85), ("Telefon & Internet", false, 120), ("Serafe", false, 335.0 / 12),
            ("Haushalt (Lebensmittel)", false, 800), ("Essen auswärts", false, 200), ("Hygiene & Kosmetik", false, 100),
            ("Kleider / Schuhe", false, 150), ("Ferien", false, 300), ("Geschenke", false, 50),
            ("Steuern", false, 1100), ("Säule 3a", false, 300), ("Sparen", false, 500),
            ("Lohn", true, 7800),
        ]
        for (index, entry) in items.enumerated() {
            let amounts = Array(repeating: (entry.2 * 100).rounded() / 100, count: 12)
            let item = PlanItem(title: entry.0, category: CategoryStyle.autoCategory(for: entry.0, isIncome: entry.1),
                                isIncome: entry.1, amounts: amounts, sortOrder: index)
            context.insert(item)
            item.plan = plan
        }
        return plan
    }

    @MainActor
    static func insert(into context: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        let existing = (try? context.fetch(FetchDescriptor<BudgetPlan>())) ?? []
        if !existing.contains(where: { $0.year == today.year }) {
            insertPlan(into: context, year: today.year, name: "\(today.year) Beispiel")
        }

        var rng = Generator(state: 42)
        let cal = Calendar.current
        func add(_ date: Date, _ title: String, _ category: String, _ amount: Double, income: Bool = false) {
            guard date <= today else { return }
            context.insert(Booking(date: date, title: title, category: category,
                                   amount: (amount * 20).rounded() / 20, isIncome: income))
        }

        for offset in (0..<3).reversed() {
            let month = today.startOfMonth.addingMonths(-offset)
            func day(_ d: Int) -> Date { cal.date(byAdding: .day, value: d - 1, to: month) ?? month }

            add(day(25), "Lohn", "Lohn", 7800, income: true)
            add(day(1), "Miete", "Wohnen", 1950)
            add(day(3), "Krankenkasse", "Krankenkasse", 520)
            add(day(6), "Netflix", "Kommunikation & Medien", 18.90)
            add(day(8), "Swisscom", "Kommunikation & Medien", 109)
            add(day(10), "Fitnessstudio", "Gesundheit & Pflege", 79)
            for week in 0..<5 {
                add(day(2 + week * 7), "Wocheneinkauf", "Lebensmittel", Double.random(in: 150...230, using: &rng))
            }
            for _ in 0..<Int.random(in: 3...6, using: &rng) {
                add(day(Int.random(in: 1...28, using: &rng)), "Restaurant", "Verpflegung", Double.random(in: 28...95, using: &rng))
            }
            for _ in 0..<Int.random(in: 10...16, using: &rng) {
                add(day(Int.random(in: 1...28, using: &rng)), "Kaffee", "Verpflegung", Double.random(in: 4.5...7.5, using: &rng))
            }
            for _ in 0..<Int.random(in: 1...3, using: &rng) {
                add(day(Int.random(in: 1...28, using: &rng)), "Kleider", "Kleidung", Double.random(in: 40...180, using: &rng))
            }
        }
    }
}
