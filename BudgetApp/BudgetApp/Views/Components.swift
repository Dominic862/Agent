import SwiftUI
import UIKit

struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.headline)
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MonthSwitcher: View {
    @Binding var month: Date

    var body: some View {
        HStack {
            Button { month = month.addingMonths(-1) } label: {
                Image(systemName: "chevron.left").padding(8)
            }
            Spacer()
            Text(month.monthTitle)
                .font(.headline)
                .onTapGesture { month = Date().startOfMonth }
            Spacer()
            Button { month = month.addingMonths(1) } label: {
                Image(systemName: "chevron.right").padding(8)
            }
        }
        .buttonStyle(.borderless)
    }
}

struct CategoryIcon: View {
    let category: String
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: CategoryStyle.icon(for: category))
            .font(.system(size: size * 0.45))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(CategoryStyle.color(for: category), in: Circle())
    }
}

struct BudgetProgressRow: View {
    let category: String
    let spent: Double
    let limit: Double
    let currency: String

    private var ratio: Double { limit > 0 ? spent / limit : 0 }
    private var tint: Color { ratio > 1 ? .red : ratio > 0.8 ? .orange : .green }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                CategoryIcon(category: category, size: 24)
                Text(category).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(spent.currencyShort(currency)) / \(limit.currencyShort(currency))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ratio > 1 ? Color.red : Color.secondary)
            }
            ProgressView(value: min(ratio, 1))
                .tint(tint)
            if ratio > 1 {
                Text("\((spent - limit).currency(currency)) über Budget")
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else {
                Text("Noch \((limit - spent).currency(currency)) verfügbar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct InsightCard: View {
    let insight: Insight
    let currency: String

    private var color: Color {
        switch insight.kind {
        case .warning: .orange
        case .tip: .blue
        case .positive: .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).font(.subheadline.weight(.semibold))
                Text(insight.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let savings = insight.savings, savings > 0 {
                    Text("Potenzial: \(savings.currency(currency)) / Monat")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.15), in: Capsule())
                        .foregroundStyle(color)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// System-Teilen-Dialog (enthält «In Dateien sichern», Mail, AirDrop usw.).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
