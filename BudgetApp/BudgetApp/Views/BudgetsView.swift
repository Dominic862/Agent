import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Binding var month: Date
    @Environment(\.modelContext) private var context
    @Query(sort: \CategoryBudget.category) private var budgets: [CategoryBudget]
    @Query private var bookings: [Booking]
    @AppStorage("currency") private var currency = "CHF"
    @State private var editing: CategoryBudget?
    @State private var showingNew = false

    var body: some View {
        let spent = Dictionary(uniqueKeysWithValues:
            Analytics.expensesByCategory(Analytics.inMonth(bookings, month)).map { ($0.category, $0.amount) })
        let budgeted = Set(budgets.map(\.category))
        let suggestions = Analytics.suggestedBudgets(bookings, month: month)
            .filter { !budgeted.contains($0.key) }
            .map { CategoryTotal(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
        let totalLimit = budgets.reduce(0) { $0 + $1.monthlyLimit }
        let totalSpent = budgets.reduce(0) { $0 + (spent[$1.category] ?? 0) }

        NavigationStack {
            List {
                Section {
                    MonthSwitcher(month: $month)
                }

                if !budgets.isEmpty {
                    Section("Gesamt") {
                        BudgetProgressRow(category: "Alle Budgets", spent: totalSpent, limit: totalLimit, currency: currency)
                    }
                }

                Section {
                    ForEach(budgets) { budget in
                        Button { editing = budget } label: {
                            BudgetProgressRow(category: budget.category, spent: spent[budget.category] ?? 0,
                                              limit: budget.monthlyLimit, currency: currency)
                        }
                        .tint(Color.primary)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(budgets[index]) }
                    }
                } header: {
                    Text("Monatsbudgets")
                } footer: {
                    if budgets.isEmpty {
                        Text("Noch keine Budgets. Übernimm die Vorschläge unten oder tippe auf +.")
                    }
                }

                if !suggestions.isEmpty {
                    Section {
                        ForEach(suggestions) { item in
                            HStack {
                                CategoryIcon(category: item.category, size: 24)
                                Text(item.category)
                                Spacer()
                                Button("+ \(item.amount.currencyShort(currency))") {
                                    context.insert(CategoryBudget(category: item.category, monthlyLimit: item.amount))
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                        Button("Alle Vorschläge übernehmen") {
                            for item in suggestions {
                                context.insert(CategoryBudget(category: item.category, monthlyLimit: item.amount))
                            }
                        }
                    } header: {
                        Text("Vorschläge")
                    } footer: {
                        Text("Basierend auf deinen durchschnittlichen Ausgaben der letzten drei Monate. Tipp: Setze variable Kategorien 10 % tiefer an, um aktiv zu sparen.")
                    }
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { BudgetEditor(budget: $0) }
            .sheet(isPresented: $showingNew) { BudgetEditor(budget: nil) }
        }
    }
}

struct BudgetEditor: View {
    let budget: CategoryBudget?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("currency") private var currency = "CHF"
    @State private var category: String
    @State private var limitText: String

    init(budget: CategoryBudget?) {
        self.budget = budget
        _category = State(initialValue: budget?.category ?? "")
        _limitText = State(initialValue: budget.map { String(format: "%.0f", $0.monthlyLimit) } ?? "")
    }

    private var limit: Double? { BudgetImporter.parseAmount(limitText).map(abs) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kategorie") {
                    TextField("z. B. Lebensmittel", text: $category)
                    if budget == nil {
                        Menu("Aus Vorlage wählen") {
                            ForEach(CategoryStyle.expenseDefaults, id: \.self) { name in
                                Button(name) { category = name }
                            }
                        }
                    }
                }
                Section("Monatsbudget") {
                    HStack {
                        Text(currency).foregroundStyle(.secondary)
                        TextField("0", text: $limitText).keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle(budget == nil ? "Neues Budget" : "Budget bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        guard let limit, limit > 0 else { return }
                        let name = category.trimmingCharacters(in: .whitespaces)
                        if let budget {
                            budget.category = name
                            budget.monthlyLimit = limit
                        } else {
                            context.insert(CategoryBudget(category: name, monthlyLimit: limit))
                        }
                        dismiss()
                    }
                    .disabled((limit ?? 0) <= 0 || category.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
