import Foundation

struct Insight: Identifiable {
    enum Kind: Int {
        case warning, tip, positive
    }

    let id = UUID()
    let kind: Kind
    let icon: String
    let title: String
    let message: String
    var savings: Double? = nil
}

/// Regelbasierte Verbesserungsvorschläge für einen Monat.
enum InsightEngine {
    static func insights(bookings: [Booking], budgets: [CategoryBudget], month: Date,
                         currency: String, today: Date = .now) -> [Insight] {
        func fmt(_ value: Double) -> String { value.currency(currency) }

        guard !bookings.isEmpty else {
            return [Insight(kind: .tip, icon: "square.and.arrow.down",
                            title: "Starte mit deinen Daten",
                            message: "Importiere dein Budget-Excel im Tab «Excel» oder erfasse Buchungen manuell. Danach erscheinen hier persönliche Verbesserungsvorschläge.")]
        }

        let cal = Calendar.current
        let monthStart = month.startOfMonth
        let current = Analytics.inMonth(bookings, monthStart)
        guard !current.isEmpty else {
            return [Insight(kind: .tip, icon: "calendar",
                            title: "Keine Buchungen in \(monthStart.monthTitle)",
                            message: "Wähle einen anderen Monat oder erfasse Buchungen für diesen Monat.")]
        }

        var result: [Insight] = []
        let summary = Analytics.summary(bookings, month: monthStart)
        let categoryTotals = Analytics.expensesByCategory(current)
        let byCategory = Dictionary(uniqueKeysWithValues: categoryTotals.map { ($0.category, $0.amount) })

        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let isCurrentMonth = cal.isDate(today, equalTo: monthStart, toGranularity: .month)
        let dayOfMonth = isCurrentMonth ? cal.component(.day, from: today) : daysInMonth
        let progress = Double(dayOfMonth) / Double(daysInMonth)
        let remainingDays = daysInMonth - dayOfMonth

        // 1. Budgets: überschritten oder auf Kurs zur Überschreitung
        for budget in budgets where budget.monthlyLimit > 0 {
            let spent = byCategory[budget.category] ?? 0
            let limit = budget.monthlyLimit
            if spent > limit {
                result.append(Insight(
                    kind: .warning, icon: "exclamationmark.triangle.fill",
                    title: "\(budget.category): Budget überschritten",
                    message: "Ausgegeben: \(fmt(spent)) von \(fmt(limit)) – \(fmt(spent - limit)) zu viel. Gleiche den Betrag im nächsten Monat aus oder setze das Budget realistischer.",
                    savings: spent - limit))
            } else if isCurrentMonth, dayOfMonth >= 7, progress < 1, spent > 0 {
                let projected = spent / progress
                if projected > limit * 1.05 {
                    let left = limit - spent
                    let perDay = remainingDays > 0 ? left / Double(remainingDays) : left
                    result.append(Insight(
                        kind: .warning, icon: "speedometer",
                        title: "\(budget.category): auf Kurs zur Überschreitung",
                        message: "Bei diesem Tempo landest du bei ca. \(fmt(projected)) (Budget \(fmt(limit))). Für die restlichen \(remainingDays) Tage bleiben \(fmt(left)) – etwa \(fmt(perDay)) pro Tag.",
                        savings: projected - limit))
                }
            }
        }

        // 2. Sparquote (50/30/20-Regel)
        if summary.income > 0 {
            let rate = summary.balance / summary.income
            if rate < 0 {
                result.append(Insight(
                    kind: .warning, icon: "arrow.down.circle.fill",
                    title: "Mehr ausgegeben als eingenommen",
                    message: "In diesem Monat fehlen \(fmt(-summary.balance)). Setze zuerst bei variablen Ausgaben an – Restaurant, Shopping und Freizeit lassen sich am schnellsten anpassen.",
                    savings: -summary.balance))
            } else if rate < 0.2 {
                let gap = summary.income * 0.2 - summary.balance
                result.append(Insight(
                    kind: .tip, icon: "percent",
                    title: "Sparquote \(rate.percent) – Ziel 20 %",
                    message: "Nach der 50/30/20-Regel fliessen 20 % des Einkommens ins Sparen. Dafür fehlen dir \(fmt(gap)) pro Monat. Tipp: Richte am Lohntag einen Dauerauftrag aufs Sparkonto ein – was weg ist, wird nicht ausgegeben.",
                    savings: gap))
            } else {
                result.append(Insight(
                    kind: .positive, icon: "star.fill",
                    title: "Starke Sparquote: \(rate.percent)",
                    message: "Du legst \(fmt(summary.balance)) zur Seite. Prüfe, ob ein Teil davon langfristig arbeiten kann, z. B. in der Säule 3a oder einem ETF-Sparplan."))
            }
        } else if !isCurrentMonth {
            result.append(Insight(
                kind: .tip, icon: "questionmark.circle",
                title: "Keine Einnahmen erfasst",
                message: "Ohne Einnahmen lässt sich keine Sparquote berechnen. Erfasse deinen Lohn als Einnahme."))
        }

        // 3. Kategorien deutlich über dem Durchschnitt
        let averages = Analytics.averageExpensesByCategory(bookings, before: monthStart)
        let increases = byCategory.compactMap { entry -> (String, Double, Double)? in
            let (category, spent) = (entry.key, entry.value)
            guard let avg = averages[category], avg > 0, spent > avg * 1.25, spent - avg >= 50 else { return nil }
            return (category, spent, avg)
        }
        .sorted { $0.1 - $0.2 > $1.1 - $1.2 }
        for (category, spent, avg) in increases.prefix(3) {
            result.append(Insight(
                kind: .tip, icon: "arrow.up.right.circle.fill",
                title: "\(category): \(((spent - avg) / avg).percent) über dem Schnitt",
                message: "\(fmt(spent)) in diesem Monat gegenüber Ø \(fmt(avg)) in den Vormonaten. Zurück auf den Schnitt spart \(fmt(spent - avg)).",
                savings: spent - avg))
        }

        // 4. Wiederkehrende Zahlungen / Abos
        let recurring = Analytics.recurringPayments(bookings, endingAt: monthStart)
            .filter { !CategoryStyle.isHousing($0.category) }
        if !recurring.isEmpty {
            let monthly = recurring.reduce(0) { $0 + $1.monthlyAmount }
            let names = recurring.prefix(5).map { "\($0.title) (\(fmt($0.monthlyAmount)))" }.joined(separator: ", ")
            result.append(Insight(
                kind: .tip, icon: "repeat.circle.fill",
                title: "\(recurring.count) wiederkehrende Zahlungen",
                message: "Zusammen ca. \(fmt(monthly)) pro Monat bzw. \(fmt(monthly * 12)) pro Jahr: \(names). Kündige, was du selten nutzt – Jahresabos sind oft 15–20 % günstiger."))
        }

        // 5. Kleinbeträge
        let small = current.filter { !$0.isIncome && $0.amount < 20 }
        let smallSum = small.reduce(0) { $0 + $1.amount }
        if small.count >= 8 && smallSum >= 80 {
            result.append(Insight(
                kind: .tip, icon: "cup.and.saucer.fill",
                title: "Kleinbeträge summieren sich",
                message: "\(small.count) Ausgaben unter \(fmt(20)) ergeben zusammen \(fmt(smallSum)). Halbierst du sie, sparst du rund \(fmt(smallSum / 2)) pro Monat – \(fmt(smallSum * 6)) im Jahr.",
                savings: smallSum / 2))
        }

        // 6. Struktur: Wohnkosten und dominante Kategorie
        if summary.income > 0 {
            let housing = categoryTotals.filter { CategoryStyle.isHousing($0.category) }.reduce(0) { $0 + $1.amount }
            if housing / summary.income > 0.33 {
                result.append(Insight(
                    kind: .tip, icon: "house.fill",
                    title: "Wohnkosten: \((housing / summary.income).percent) des Einkommens",
                    message: "Empfohlen ist höchstens ein Drittel. Prüfe Nebenkosten, Strom- und Internetverträge – oder langfristig eine günstigere Wohnlösung."))
            }
        }
        if let top = categoryTotals.first, summary.expenses > 0, !CategoryStyle.isHousing(top.category),
           top.amount / summary.expenses > 0.4 {
            result.append(Insight(
                kind: .tip, icon: "chart.pie.fill",
                title: "\(top.category) dominiert deine Ausgaben",
                message: "\((top.amount / summary.expenses).percent) aller Ausgaben gehen in diese Kategorie (\(fmt(top.amount))). Schon 10 % weniger brächten \(fmt(top.amount * 0.1)) pro Monat.",
                savings: top.amount * 0.1))
        }

        // 7. Fehlende Budgets
        let budgeted = Set(budgets.map(\.category))
        if budgets.isEmpty {
            result.append(Insight(
                kind: .tip, icon: "target",
                title: "Lege Monatsbudgets fest",
                message: "Mit einem Budget pro Kategorie siehst du früh, wenn es eng wird. Im Tab «Budgets» findest du Vorschläge auf Basis deiner bisherigen Ausgaben."))
        } else {
            let missing = Analytics.suggestedBudgets(bookings, month: monthStart)
                .filter { !budgeted.contains($0.key) }
                .sorted { $0.value > $1.value }
                .prefix(3)
            if !missing.isEmpty {
                let list = missing.map { "\($0.key) (\(fmt($0.value)))" }.joined(separator: ", ")
                result.append(Insight(
                    kind: .tip, icon: "target",
                    title: "Budgets ergänzen",
                    message: "Für diese Kategorien gibst du regelmässig Geld aus, hast aber kein Budget: \(list)."))
            }
        }

        // 8. Lob für abgeschlossene Monate
        if !isCurrentMonth, !budgets.isEmpty,
           budgets.allSatisfy({ (byCategory[$0.category] ?? 0) <= $0.monthlyLimit }) {
            result.append(Insight(
                kind: .positive, icon: "checkmark.seal.fill",
                title: "Alle Budgets eingehalten",
                message: "Stark! Wenn das mehrere Monate in Folge klappt, kannst du die Budgets leicht senken und die Differenz sparen."))
        }

        return result.enumerated()
            .sorted { ($0.element.kind.rawValue, $0.offset) < ($1.element.kind.rawValue, $1.offset) }
            .map(\.element)
    }
}
