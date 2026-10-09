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

/// Regelbasierte Verbesserungsvorschläge – aus dem Jahresplan (Soll) und, falls erfasst, den Buchungen (Ist).
enum InsightEngine {
    static func insights(plan: BudgetPlan?, previousPlan: BudgetPlan?, bookings: [Booking],
                         month: Date, currency: String, today: Date = .now) -> [Insight] {
        func fmt(_ value: Double) -> String { value.currencyShort(currency) }

        guard plan != nil || !bookings.isEmpty else {
            return [Insight(kind: .tip, icon: "square.and.arrow.down",
                            title: "Starte mit deinem Budget-Excel",
                            message: "Importiere dein Excel im Tab «Excel» oder lege im Tab «Plan» einen Jahresplan an. Danach erscheinen hier persönliche Verbesserungsvorschläge.")]
        }

        var result: [Insight] = []
        if let plan {
            result += planInsights(plan, previous: previousPlan, month: month.monthIndex, fmt: fmt)
        }
        result += bookingInsights(bookings, plan: plan, month: month, today: today, fmt: fmt)

        return result.enumerated()
            .sorted { ($0.element.kind.rawValue, $0.offset) < ($1.element.kind.rawValue, $1.offset) }
            .map(\.element)
    }

    // MARK: - Jahresplan (Soll)

    private static func planInsights(_ plan: BudgetPlan, previous: BudgetPlan?, month m: Int,
                                     fmt: (Double) -> String) -> [Insight] {
        var result: [Insight] = []
        let names = PlanSelection.shortMonthNames
        let income = plan.income(month: m)
        let expenses = plan.expenses(month: m)
        let byCategory = plan.expensesByCategory(month: m)
        func share(_ category: String) -> Double { byCategory.first { $0.category == category }?.amount ?? 0 }

        guard plan.yearlyIncome > 0 else {
            return [Insight(kind: .tip, icon: "questionmark.circle", title: "Keine Einnahmen im Plan",
                            message: "Im Plan «\(plan.name)» sind keine Einnahmen erfasst. Ergänze Lohn und Zulagen im Tab «Plan», damit Überschuss und Sparquote berechnet werden können.")]
        }

        // 1. Monate mit Defizit
        let negative = (0..<12).filter { plan.surplus(month: $0) < -0.5 }
        if !negative.isEmpty {
            let missing = negative.reduce(0) { $0 - plan.surplus(month: $1) }
            let list = negative.map { "\(names[$0]) \(fmt(plan.surplus(month: $0)))" }.joined(separator: ", ")
            result.append(Insight(
                kind: .warning, icon: "exclamationmark.triangle.fill",
                title: "Defizit in \(negative.count) \(negative.count == 1 ? "Monat" : "Monaten")",
                message: "\(list). Über das Jahr fehlen \(fmt(missing)). Gleiche das mit dem Überschuss der anderen Monate aus, verschiebe Sparbeiträge oder senke flexible Posten in diesen Monaten.",
                savings: nil))
        }

        // 2. Zu wenig Puffer
        let thin = (0..<12).filter { i in
            let s = plan.surplus(month: i)
            return s >= -0.5 && s < plan.income(month: i) * 0.03
        }
        if !thin.isEmpty {
            let minimum = thin.map { plan.surplus(month: $0) }.min() ?? 0
            let maximum = thin.map { plan.surplus(month: $0) }.max() ?? 0
            let range = abs(maximum - minimum) < 1 ? fmt(minimum) : "\(fmt(minimum)) bis \(fmt(maximum))"
            let target = (income > 0 ? income : plan.yearlyIncome / 12) * 0.05
            let flexible = byCategory.filter { CategoryStyle.bucket(for: $0.category) == .wants }.prefix(3)
            let ideas = flexible.isEmpty ? "" :
                " Ansatzpunkte sind flexible Posten wie " + flexible.map { "\($0.category) (\(fmt($0.amount)))" }.joined(separator: ", ") + "."
            result.append(Insight(
                kind: .warning, icon: "lifepreserver",
                title: "Kaum Puffer für Unvorhergesehenes",
                message: "In \(thin.count) Monaten (\(thin.map { names[$0] }.joined(separator: ", "))) bleiben nur \(range) übrig. Eine Zahnarztrechnung oder Reparatur bringt das Budget dann ins Minus. Plane rund 5 % des Einkommens (≈ \(fmt(target)) pro Monat) als Reserve ein.\(ideas)",
                savings: max(target - minimum, 0)))
        }

        // 3. Sparquote laut Plan
        if income > 0 {
            let saving = byCategory.filter { CategoryStyle.bucket(for: $0.category) == .savings }.reduce(0) { $0 + $1.amount }
            let rate = saving / income
            if rate >= 0.15 {
                result.append(Insight(
                    kind: .positive, icon: "star.fill",
                    title: "Starke Sparquote: \(rate.percent)",
                    message: "Du planst \(fmt(saving)) pro Monat für Sparen und Vorsorge (Säule 3a/3b, Sparkonten, Rückstellungen). Achte darauf, dass die 3a-Einzahlungen den Maximalbetrag nutzen – das spart zusätzlich Steuern."))
            } else {
                let gap = income * 0.15 - saving
                result.append(Insight(
                    kind: .tip, icon: "percent",
                    title: "Sparquote \(rate.percent) – Ziel 15–20 %",
                    message: "Im \(PlanSelection.monthNames[m]) sind \(fmt(saving)) für Sparen und Vorsorge eingeplant. Für 15 % fehlen \(fmt(gap)). Ein fixer Dauerauftrag am Lohntag macht Sparen automatisch.",
                    savings: gap))
            }
        }

        // 4. Krankenkasse
        let health = share("Krankenkasse")
        if income > 0, health / income > 0.1 {
            result.append(Insight(
                kind: .tip, icon: "cross.case.fill",
                title: "Krankenkasse: \((health / income).percent) des Einkommens",
                message: "\(fmt(health)) pro Monat. Prüfe jährlich Franchise, alternative Modelle (Hausarzt, HMO, Telmed) und ob ihr Anspruch auf Prämienverbilligung habt. Kündigungsfrist für die Grundversicherung ist der 30. November.",
                savings: health * 0.1))
        }

        // 5. Wohnkosten
        let housing = share("Wohnen")
        if income > 0, housing / income > 0.33 {
            result.append(Insight(
                kind: .tip, icon: "house.fill",
                title: "Wohnkosten: \((housing / income).percent) des Einkommens",
                message: "Empfohlen ist höchstens ein Drittel. Prüfe Nebenkosten, Energie und – bei Wohneigentum – die Hypothekarstrategie."))
        }

        // 6. Telefon / Internet / Medien
        let telecom = share("Kommunikation & Medien")
        if telecom > 150 {
            result.append(Insight(
                kind: .tip, icon: "antenna.radiowaves.left.and.right",
                title: "Kommunikation & Medien: \(fmt(telecom)) pro Monat",
                message: "Internet, Handy-Abos und Streaming lohnen sich jährlich zu vergleichen. Kombi- oder Zweitmarken-Angebote sind oft deutlich günstiger, Streaming-Dienste lassen sich abwechselnd statt parallel nutzen.",
                savings: telecom * 0.25))
        }

        // 7. Jährliche Rechnungen
        let annual = share("Versicherungen") + share("Steuern")
        if annual > 0 {
            result.append(Insight(
                kind: .tip, icon: "tray.full.fill",
                title: "Rückstellungen auf separates Konto",
                message: "Für Versicherungen und Steuern sind \(fmt(annual)) pro Monat eingeplant. Diese Rechnungen kommen meist jährlich oder quartalsweise – ein eigenes Konto mit Dauerauftrag sorgt dafür, dass das Geld bereitliegt und nicht im Alltag verschwindet."))
        }

        // 8. Vergleich mit dem Vorjahr
        if let previous, previous.yearlyExpenses > 0 {
            let now = Dictionary(uniqueKeysWithValues: plan.expensesByCategory(month: nil).map { ($0.category, $0.amount) })
            let before = Dictionary(uniqueKeysWithValues: previous.expensesByCategory(month: nil).map { ($0.category, $0.amount) })

            if let taxBefore = before["Steuern"], let taxNow = now["Steuern"], taxNow < taxBefore * 0.9 {
                result.append(Insight(
                    kind: .warning, icon: "building.columns.fill",
                    title: "Steuern tiefer budgetiert als im Vorjahr",
                    message: "\(plan.name): \(fmt(taxNow)) statt \(fmt(taxBefore)) im \(previous.name). Steuerrechnungen sind schwer planbar – prüfe die provisorische Rechnung und budgetiere lieber etwas zu viel als zu wenig."))
            }

            let increases = now.compactMap { entry -> (String, Double)? in
                let delta = entry.value - (before[entry.key] ?? 0)
                return delta > 600 && CategoryStyle.bucket(for: entry.key) != .savings ? (entry.key, delta) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            if !increases.isEmpty {
                let list = increases.map { "\($0.0) +\(fmt($0.1))" }.joined(separator: ", ")
                let total = plan.yearlyExpenses - previous.yearlyExpenses
                result.append(Insight(
                    kind: .tip, icon: "chart.line.uptrend.xyaxis",
                    title: "Grösste Mehrkosten gegenüber \(previous.name)",
                    message: "\(list) pro Jahr. Insgesamt sind die geplanten Ausgaben \(total >= 0 ? "um \(fmt(total)) gestiegen" : "um \(fmt(-total)) gesunken"). Lohnt sich bei einem dieser Posten ein Vergleich oder eine Verhandlung?"))
            }
        }

        // 9. 50/30/20-Aufteilung
        if income > 0 {
            let needs = byCategory.filter { CategoryStyle.bucket(for: $0.category) == .needs }.reduce(0) { $0 + $1.amount }
            if needs / income > 0.65 {
                result.append(Insight(
                    kind: .tip, icon: "chart.bar.fill",
                    title: "Fixkosten: \((needs / income).percent) des Einkommens",
                    message: "Richtwert sind rund 50 %. Hohe Fixkosten machen das Budget unflexibel – grössere Hebel sind meist Wohnen, Mobilität und Versicherungen."))
            }
        }

        if expenses > 0, income > 0, negative.isEmpty, thin.isEmpty {
            result.append(Insight(
                kind: .positive, icon: "checkmark.seal.fill",
                title: "Plan ist das ganze Jahr gedeckt",
                message: "In jedem Monat bleibt ein Überschuss. Im \(PlanSelection.monthNames[m]) sind es \(fmt(income - expenses))."))
        }
        return result
    }

    // MARK: - Buchungen (Ist)

    private static func bookingInsights(_ bookings: [Booking], plan: BudgetPlan?, month: Date, today: Date,
                                        fmt: (Double) -> String) -> [Insight] {
        let cal = Calendar.current
        let monthStart = month.startOfMonth
        let current = Analytics.inMonth(bookings, monthStart)
        var result: [Insight] = []

        guard !current.isEmpty else {
            if plan != nil, cal.isDate(today, equalTo: monthStart, toGranularity: .month) {
                result.append(Insight(
                    kind: .tip, icon: "list.bullet.rectangle",
                    title: "Soll/Ist-Vergleich aktivieren",
                    message: "Erfasse im Tab «Buchungen» deine tatsächlichen Ausgaben (oder importiere einen Bank-Export als CSV). Dann zeigt die App, wo du über dem Plan liegst – genau das, was im Excel im Block «Ausgaben» vorgesehen war."))
            }
            return result
        }

        let byCategory = Dictionary(uniqueKeysWithValues: Analytics.expensesByCategory(current).map { ($0.category, $0.amount) })
        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let isCurrentMonth = cal.isDate(today, equalTo: monthStart, toGranularity: .month)
        let dayOfMonth = isCurrentMonth ? cal.component(.day, from: today) : daysInMonth
        let progress = Double(dayOfMonth) / Double(daysInMonth)

        // Soll/Ist pro Kategorie
        if let plan {
            for planned in plan.expensesByCategory(month: month.monthIndex) {
                let spent = byCategory[planned.category] ?? 0
                if spent > planned.amount * 1.02 {
                    result.append(Insight(
                        kind: .warning, icon: "exclamationmark.circle.fill",
                        title: "\(planned.category): über Plan",
                        message: "Ausgegeben: \(fmt(spent)) – geplant waren \(fmt(planned.amount)) (+\(fmt(spent - planned.amount))).",
                        savings: spent - planned.amount))
                } else if isCurrentMonth, dayOfMonth >= 7, progress < 1, spent > 0, spent / progress > planned.amount * 1.1,
                          CategoryStyle.bucket(for: planned.category) == .wants || planned.category == "Lebensmittel" {
                    let left = planned.amount - spent
                    let days = daysInMonth - dayOfMonth
                    result.append(Insight(
                        kind: .warning, icon: "speedometer",
                        title: "\(planned.category): auf Kurs zur Überschreitung",
                        message: "Hochgerechnet ca. \(fmt(spent / progress)) statt \(fmt(planned.amount)). Für die restlichen \(days) Tage bleiben \(fmt(left)) – etwa \(fmt(days > 0 ? left / Double(days) : left)) pro Tag."))
                }
            }
        }

        // Kategorien über dem Durchschnitt der Vormonate
        let averages = Analytics.averageExpensesByCategory(bookings, before: monthStart)
        let increases = byCategory.compactMap { entry -> (String, Double, Double)? in
            guard let avg = averages[entry.key], avg > 0, entry.value > avg * 1.25, entry.value - avg >= 50 else { return nil }
            return (entry.key, entry.value, avg)
        }
        .sorted { $0.1 - $0.2 > $1.1 - $1.2 }
        for (category, spent, avg) in increases.prefix(2) {
            result.append(Insight(
                kind: .tip, icon: "arrow.up.right.circle.fill",
                title: "\(category): \(((spent - avg) / avg).percent) über dem Schnitt",
                message: "\(fmt(spent)) in diesem Monat gegenüber Ø \(fmt(avg)) in den Vormonaten.",
                savings: spent - avg))
        }

        // Wiederkehrende Zahlungen
        let recurring = Analytics.recurringPayments(bookings, endingAt: monthStart)
            .filter { !CategoryStyle.isHousing($0.category) }
        if !recurring.isEmpty {
            let monthly = recurring.reduce(0) { $0 + $1.monthlyAmount }
            let names = recurring.prefix(5).map { "\($0.title) (\(fmt($0.monthlyAmount)))" }.joined(separator: ", ")
            result.append(Insight(
                kind: .tip, icon: "repeat.circle.fill",
                title: "\(recurring.count) wiederkehrende Zahlungen",
                message: "Zusammen ca. \(fmt(monthly)) pro Monat bzw. \(fmt(monthly * 12)) pro Jahr: \(names). Kündige, was du selten nutzt."))
        }

        // Kleinbeträge
        let small = current.filter { !$0.isIncome && $0.amount < 20 }
        let smallSum = small.reduce(0) { $0 + $1.amount }
        if small.count >= 8 && smallSum >= 80 {
            result.append(Insight(
                kind: .tip, icon: "cup.and.saucer.fill",
                title: "Kleinbeträge summieren sich",
                message: "\(small.count) Ausgaben unter \(fmt(20)) ergeben zusammen \(fmt(smallSum)). Halbierst du sie, sparst du rund \(fmt(smallSum / 2)) pro Monat.",
                savings: smallSum / 2))
        }

        // Ohne Plan: Sparquote aus den Buchungen
        if plan == nil {
            let summary = Analytics.summary(bookings, month: monthStart)
            if summary.income > 0, let rate = summary.savingsRate {
                result.append(rate < 0
                    ? Insight(kind: .warning, icon: "arrow.down.circle.fill", title: "Mehr ausgegeben als eingenommen",
                              message: "In diesem Monat fehlen \(fmt(-summary.balance)).", savings: -summary.balance)
                    : Insight(kind: rate >= 0.15 ? .positive : .tip, icon: "percent", title: "Sparquote: \(rate.percent)",
                              message: "Übrig bleiben \(fmt(summary.balance)) von \(fmt(summary.income)). Richtwert: 15–20 %."))
            }
        }
        return result
    }
}
