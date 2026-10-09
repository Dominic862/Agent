import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Binding var month: Date
    @Query(sort: \Booking.date, order: .reverse) private var bookings: [Booking]
    @Query(sort: \CategoryBudget.category) private var budgets: [CategoryBudget]
    @AppStorage("currency") private var currency = "CHF"

    var body: some View {
        let monthBookings = Analytics.inMonth(bookings, month)
        let summary = Analytics.summary(bookings, month: month)
        let categories = Analytics.expensesByCategory(monthBookings)
        let trend = Analytics.trend(bookings, endingAt: month)
        let insights = InsightEngine.insights(bookings: bookings, budgets: budgets, month: month, currency: currency)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthSwitcher(month: $month)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(title: "Einnahmen", value: summary.income.currencyShort(currency),
                                 icon: "arrow.down.circle.fill", color: .green)
                        StatTile(title: "Ausgaben", value: summary.expenses.currencyShort(currency),
                                 icon: "arrow.up.circle.fill", color: .red)
                        StatTile(title: "Saldo", value: summary.balance.currencyShort(currency),
                                 icon: "equal.circle.fill", color: summary.balance >= 0 ? .blue : .red)
                        StatTile(title: "Sparquote", value: summary.savingsRate?.percent ?? "–",
                                 icon: "banknote.fill", color: .purple)
                    }

                    if categories.isEmpty {
                        Card {
                            ContentUnavailableView("Keine Ausgaben",
                                                   systemImage: "tray",
                                                   description: Text("Importiere dein Excel im Tab «Excel» oder erfasse eine Buchung."))
                        }
                    } else {
                        categoryCard(categories, total: summary.expenses)
                    }

                    if !budgets.isEmpty {
                        budgetCard(categories)
                    }

                    trendCard(trend)

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

    private func categoryCard(_ categories: [CategoryTotal], total: Double) -> some View {
        Card(title: "Ausgaben nach Kategorie") {
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
                    Text(item.category).font(.subheadline)
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

    private func budgetCard(_ categories: [CategoryTotal]) -> some View {
        let spent = Dictionary(uniqueKeysWithValues: categories.map { ($0.category, $0.amount) })
        return Card(title: "Budgets") {
            ForEach(budgets) { budget in
                BudgetProgressRow(category: budget.category, spent: spent[budget.category] ?? 0,
                                  limit: budget.monthlyLimit, currency: currency)
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

            let withIncome = trend.filter { $0.income > 0 }
            if !withIncome.isEmpty {
                let avgSaved = withIncome.reduce(0) { $0 + $1.balance } / Double(withIncome.count)
                Text("Ø Saldo pro Monat: \(avgSaved.currency(currency))")
                    .font(.footnote)
                    .foregroundStyle(avgSaved >= 0 ? Color.secondary : Color.red)
            }
        }
    }
}
