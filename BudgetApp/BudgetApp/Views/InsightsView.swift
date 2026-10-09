import SwiftUI
import SwiftData

struct InsightsView: View {
    @Binding var month: Date
    @Query(sort: \BudgetPlan.sortOrder) private var plans: [BudgetPlan]
    @Query private var bookings: [Booking]
    @AppStorage("currency") private var currency = "CHF"
    @AppStorage("activePlan") private var activePlan = ""

    var body: some View {
        let plan = PlanSelection.plan(for: month, in: plans, preferred: activePlan)
        let previous = plan.flatMap { PlanSelection.previousPlan(before: $0, in: plans) }
        let insights = InsightEngine.insights(plan: plan, previousPlan: previous, bookings: bookings,
                                              month: month, currency: currency)
        let potential = insights.compactMap(\.savings).filter { $0 > 0 }.reduce(0, +)

        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    MonthSwitcher(month: $month)
                    if let plan {
                        Text(basis(plan, previous))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if potential > 0 {
                        Card {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.title)
                                    .foregroundStyle(.yellow)
                                VStack(alignment: .leading) {
                                    Text("Mögliches Potenzial").font(.caption).foregroundStyle(.secondary)
                                    Text("bis \(potential.currencyShort(currency)) / Monat").font(.title3.weight(.semibold))
                                    Text("≈ \((potential * 12).currencyShort(currency)) pro Jahr").font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    ForEach(insights) { InsightCard(insight: $0, currency: currency) }

                    Text("Die Tipps basieren auf Richtwerten (50/30/20-Regel, max. ⅓ fürs Wohnen, 5 % Reserve), deinem Jahresplan, dem Vergleich mit dem Vorjahr und – falls erfasst – deinen Buchungen. Einzelne Potenziale können sich überschneiden.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Verbesserungen")
        }
    }

    private func basis(_ plan: BudgetPlan, _ previous: BudgetPlan?) -> String {
        var text = "Basis: Plan «\(plan.name)»"
        if let previous { text += " · Vergleich mit «\(previous.name)»" }
        return text
    }
}
