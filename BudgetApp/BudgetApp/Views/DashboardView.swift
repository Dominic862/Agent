import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Binding var month: Date
    @Query(sort: \BudgetPlan.sortOrder) private var plans: [BudgetPlan]
    @Query(sort: \Booking.date, order: .reverse) private var bookings: [Booking]
    @AppStorage("currency") private var currency = "CHF"
    @AppStorage("activePlan") private var activePlan = ""

    var body: some View {
        let plan = PlanSelection.plan(for: month, in: plans, preferred: activePlan)
        let previous = plan.flatMap { PlanSelection.previousPlan(before: $0, in: plans) }
        let monthBookings = Analytics.inMonth(bookings, month)
        let insights = InsightEngine.insights(plan: plan, previousPlan: previous, bookings: bookings,
                                              month: month, currency: currency)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthSwitcher(month: $month)

                    if let plan {
                        planPicker(current: plan)
                        planContent(plan, bookings: monthBookings)
                    } else {
                        if !plans.isEmpty {
                            Card {
                                Label("Kein Jahresplan für \(String(month.year)). Lege im Tab «Plan» eine Kopie des Vorjahres an.",
                                      systemImage: "calendar.badge.exclamationmark")
                                    .font(.subheadline)
                            }
                        }
                        bookingContent(monthBookings)
                    }

                    if !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top-Tipps").font(.headline).padding(.horizontal, 4)
                            ForEach(insights.prefix(3)) { InsightCard(insight: $0, currency: currency) }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Übersicht")
        }
    }

    // MARK: - Mit Jahresplan

    @ViewBuilder
    private func planPicker(current: BudgetPlan) -> some View {
        let sameYear = plans.filter { $0.year == current.year }
        if sameYear.count > 1 {
            Picker("Variante", selection: Binding(get: { current.name }, set: { activePlan = $0 })) {
                ForEach(sameYear) { Text($0.name).tag($0.name) }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private func planContent(_ plan: BudgetPlan, bookings: [Booking]) -> some View {
        let m = month.monthIndex
        let income = plan.income(month: m)
        let expenses = plan.expenses(month: m)
        let surplus = income - expenses
        let categories = plan.expensesByCategory(month: m)
        let saving = categories.filter { CategoryStyle.bucket(for: $0.category) == .savings }.reduce(0) { $0 + $1.amount }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Einnahmen", value: income.currencyShort(currency), icon: "arrow.down.circle.fill", color: .green)
            StatTile(title: "Ausgaben", value: expenses.currencyShort(currency), icon: "arrow.up.circle.fill", color: .red)
            StatTile(title: "Überschuss", value: surplus.currency(currency), icon: "equal.circle.fill",
                     color: surplus < 0 ? .red : surplus < income * 0.03 ? .orange : .blue)
            StatTile(title: "Sparquote", value: income > 0 ? (saving / income).percent : "–", icon: "banknote.fill", color: .purple)
        }

        surplusCard(plan)

        if !categories.isEmpty {
            categoryCard(title: "Geplante Ausgaben nach Kategorie", categories: categories, total: expenses)
        }

        if income > 0 {
            bucketCard(categories: categories, income: income)
        }

        if !bookings.isEmpty {
            sollIstCard(planned: categories, bookings: bookings)
        }
    }

    private func surplusCard(_ plan: BudgetPlan) -> some View {
        let names = PlanSelection.shortMonthNames
        let m = month.monthIndex
        return Card(title: "Überschuss pro Monat · \(plan.title)") {
            Chart {
                ForEach(0..<12, id: \.self) { i in
                    let value = plan.surplus(month: i)
                    BarMark(x: .value("Monat", names[i]), y: .value("Überschuss", value))
                        .foregroundStyle(value < 0 ? Color.red : value < plan.income(month: i) * 0.03 ? Color.orange : Color.green)
                        .opacity(i == m ? 1 : 0.45)
                }
                RuleMark(y: .value("Null", 0)).foregroundStyle(Color.secondary)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let name = value.as(String.self) { Text(String(name.prefix(1))) }
                    }
                }
            }
            .frame(height: 170)

            let total = plan.yearlyIncome - plan.yearlyExpenses
            HStack {
                Text("Jahr: \(total.currencyShort(currency))")
                    .foregroundStyle(total < 0 ? Color.red : Color.primary)
                Spacer()
                Text("Ausgaben \(plan.yearlyExpenses.currencyShort(currency))")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
    }

    private func bucketCard(categories: [CategoryTotal], income: Double) -> some View {
        let totals = CategoryStyle.Bucket.allCases.map { bucket in
            BucketTotal(bucket: bucket,
                        amount: categories.filter { CategoryStyle.bucket(for: $0.category) == bucket }.reduce(0) { $0 + $1.amount })
        }
        return Card(title: "Aufteilung (Richtwert 50/30/20)") {
            Chart {
                ForEach(totals) { total in
                    BarMark(x: .value("Betrag", total.amount), y: .value("Plan", "Plan"))
                        .foregroundStyle(total.bucket.color)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 28)

            ForEach(totals) { total in
                HStack {
                    Circle().fill(total.bucket.color).frame(width: 10, height: 10)
                    Text(total.bucket.rawValue).font(.subheadline)
                    Spacer()
                    Text(total.amount.currencyShort(currency)).font(.subheadline.monospacedDigit())
                    Text("\((total.amount / income).percent) / \(total.bucket.target.percent)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 72, alignment: .trailing)
                }
            }
        }
    }

    private func sollIstCard(planned: [CategoryTotal], bookings: [Booking]) -> some View {
        let spent = Dictionary(uniqueKeysWithValues: Analytics.expensesByCategory(bookings).map { ($0.category, $0.amount) })
        let rows = planned.filter { (spent[$0.category] ?? 0) > 0 || CategoryStyle.bucket(for: $0.category) == .wants }
        let unplanned = spent.filter { entry in !planned.contains { $0.category == entry.key } }
        return Card(title: "Soll / Ist") {
            ForEach(rows) { row in
                BudgetProgressRow(category: row.category, spent: spent[row.category] ?? 0,
                                  limit: row.amount, currency: currency)
            }
            if !unplanned.isEmpty {
                Text("Nicht geplant: " + unplanned.map { "\($0.key) \($0.value.currencyShort(currency))" }.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Nur Buchungen

    @ViewBuilder
    private func bookingContent(_ monthBookings: [Booking]) -> some View {
        let summary = Analytics.summary(bookings, month: month)
        let categories = Analytics.expensesByCategory(monthBookings)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Einnahmen", value: summary.income.currencyShort(currency), icon: "arrow.down.circle.fill", color: .green)
            StatTile(title: "Ausgaben", value: summary.expenses.currencyShort(currency), icon: "arrow.up.circle.fill", color: .red)
            StatTile(title: "Saldo", value: summary.balance.currencyShort(currency), icon: "equal.circle.fill",
                     color: summary.balance >= 0 ? .blue : .red)
            StatTile(title: "Sparquote", value: summary.savingsRate?.percent ?? "–", icon: "banknote.fill", color: .purple)
        }

        if categories.isEmpty {
            Card {
                ContentUnavailableView("Noch keine Daten", systemImage: "tablecells",
                                       description: Text("Importiere dein Budget-Excel im Tab «Excel»."))
            }
        } else {
            categoryCard(title: "Ausgaben nach Kategorie", categories: categories, total: summary.expenses)
        }
        trendCard(Analytics.trend(bookings, endingAt: month))
    }

    // MARK: - Bausteine

    private func categoryCard(title: String, categories: [CategoryTotal], total: Double) -> some View {
        Card(title: title) {
            Chart(categories) { item in
                SectorMark(angle: .value("Betrag", item.amount), innerRadius: .ratio(0.62), angularInset: 1.5)
                    .foregroundStyle(CategoryStyle.color(for: item.category))
                    .cornerRadius(4)
            }
            .frame(height: 210)
            .chartBackground { _ in
                VStack {
                    Text("Total").font(.caption).foregroundStyle(.secondary)
                    Text(total.currencyShort(currency)).font(.headline)
                }
            }

            ForEach(categories) { item in
                HStack {
                    CategoryIcon(category: item.category, size: 24)
                    Text(item.category).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text((item.amount / max(total, 1)).percent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.amount.currency(currency))
                        .font(.subheadline.monospacedDigit())
                        .frame(minWidth: 90, alignment: .trailing)
                }
            }
        }
    }

    private func trendCard(_ trend: [MonthSummary]) -> some View {
        Card(title: "Verlauf (6 Monate)") {
            Chart {
                ForEach(trend) { s in
                    BarMark(x: .value("Monat", s.month, unit: .month), y: .value("Betrag", s.income))
                        .foregroundStyle(by: .value("Art", "Einnahmen"))
                        .position(by: .value("Art", "Einnahmen"))
                    BarMark(x: .value("Monat", s.month, unit: .month), y: .value("Betrag", s.expenses))
                        .foregroundStyle(by: .value("Art", "Ausgaben"))
                        .position(by: .value("Art", "Ausgaben"))
                }
            }
            .chartForegroundStyleScale(["Einnahmen": Color.green, "Ausgaben": Color.red])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .frame(height: 200)
        }
    }
}

private struct BucketTotal: Identifiable {
    let bucket: CategoryStyle.Bucket
    let amount: Double
    var id: String { bucket.rawValue }
}
