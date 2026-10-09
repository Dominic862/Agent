import Foundation
import SwiftData

/// Beispieldaten für die letzten sechs Monate, um die App auszuprobieren.
enum SampleData {
    private struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    @MainActor
    static func insert(into context: ModelContext) {
        var rng = Generator(state: 42)
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        func add(_ date: Date, _ title: String, _ category: String, _ amount: Double, income: Bool = false) {
            guard date <= today else { return }
            context.insert(Booking(date: date, title: title, category: category,
                                   amount: (amount * 20).rounded() / 20, isIncome: income))
        }

        for offset in (0..<6).reversed() {
            let month = today.startOfMonth.addingMonths(-offset)
            func day(_ d: Int) -> Date { cal.date(byAdding: .day, value: d - 1, to: month) ?? month }

            add(day(25), "Lohn", "Lohn", 6_400, income: true)
            if offset % 3 == 0 { add(day(12), "Nebenjob", "Nebeneinkommen", 450, income: true) }
            add(day(1), "Miete", "Wohnen", 1_850)
            add(day(3), "Krankenkasse", "Versicherungen", 412.40)
            add(day(5), "Strom & Internet", "Wohnen", 129.90)
            add(day(6), "Netflix", "Abos", 18.90)
            add(day(8), "Spotify", "Abos", 12.95)
            add(day(10), "Fitnessstudio", "Abos", 79)
            add(day(2), "Handy-Abo", "Abos", 39.90)
            add(day(1), "ÖV-Abo", "Transport", 85)
            add(day(26), "Dauerauftrag Säule 3a", "Sparen", 500)

            for week in 0..<5 {
                add(day(2 + week * 7), "Wocheneinkauf", "Lebensmittel", Double.random(in: 95...170, using: &rng))
            }
            for _ in 0..<Int.random(in: 3...7, using: &rng) {
                add(day(Int.random(in: 1...28, using: &rng)), "Restaurant", "Restaurant", Double.random(in: 28...95, using: &rng))
            }
            for _ in 0..<Int.random(in: 10...16, using: &rng) {
                add(day(Int.random(in: 1...28, using: &rng)), "Kaffee", "Restaurant", Double.random(in: 4.5...7.5, using: &rng))
            }
            for _ in 0..<Int.random(in: 1...3, using: &rng) {
                add(day(Int.random(in: 1...28, using: &rng)), "Kleider", "Shopping", Double.random(in: 40...180, using: &rng))
            }
            add(day(Int.random(in: 5...25, using: &rng)), "Kino & Ausgang", "Freizeit", Double.random(in: 40...140, using: &rng))
            if offset == 1 { add(day(14), "Flug Lissabon", "Reisen", 389) }
        }

        let budgets: [(String, Double)] = [("Lebensmittel", 600), ("Restaurant", 300), ("Shopping", 200), ("Freizeit", 150)]
        for (category, limit) in budgets {
            context.insert(CategoryBudget(category: category, monthlyLimit: limit))
        }
    }
}
