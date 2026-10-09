import SwiftUI
import SwiftData

struct InsightsView: View {
    @Binding var month: Date
    @Query private var bookings: [Booking]
    @Query private var budgets: [CategoryBudget]
    @AppStorage("currency") private var currency = "CHF"

    var body: some View {
        let insights = InsightEngine.insights(bookings: bookings, budgets: budgets, month: month, currency: currency)
        let potential = insights.compactMap(\.savings).filter { $0 > 0 }.reduce(0, +)

        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    MonthSwitcher(month: $month)

                    if potential > 0 {
                        Card {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.title)
                                    .foregroundStyle(.yellow)
                                VStack(alignment: .leading) {
                                    Text("Sparpotenzial").font(.caption).foregroundStyle(.secondary)
                                    Text("bis \(potential.currencyShort(currency)) / Monat").font(.title3.weight(.semibold))
                                    Text("≈ \((potential * 12).currencyShort(currency)) pro Jahr").font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    ForEach(insights) { InsightCard(insight: $0, currency: currency) }

                    Text("Die Tipps basieren auf Regeln wie 50/30/20, deinen Budgets und dem Vergleich mit den Vormonaten. Einzelne Potenziale können sich überschneiden.")
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
}
