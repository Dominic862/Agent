import SwiftUI
import SwiftData

/// Der Jahresplan wie im Excel: Posten pro Kategorie, Beträge pro Monat oder Jahr, Einnahmen und Überschuss.
struct PlanView: View {
    @Binding var month: Date
    @Environment(\.modelContext) private var context
    @Query(sort: \BudgetPlan.sortOrder) private var plans: [BudgetPlan]
    @AppStorage("activePlan") private var activePlan = ""
    @AppStorage("currency") private var currency = "CHF"

    @State private var showYearly = false
    @State private var editingItem: PlanItem?
    @State private var newItem: NewItemRequest?
    @State private var editingPlan = false
    @State private var nameDraft = ""
    @State private var yearDraft = ""
    @State private var confirmDelete = false

    private struct NewItemRequest: Identifiable {
        let id = UUID()
        let isIncome: Bool
    }

    private struct CategoryGroup: Identifiable {
        let category: String
        let items: [PlanItem]
        let total: Double
        var id: String { category }
    }

    private var plan: BudgetPlan? {
        PlanSelection.plan(for: month, in: plans, preferred: activePlan)
            ?? plans.first { $0.name == activePlan }
            ?? plans.first
    }

    private func value(_ item: PlanItem) -> Double { showYearly ? item.yearly : item.amount(month: month.monthIndex) }

    var body: some View {
        NavigationStack {
            Group {
                if let plan {
                    planList(plan)
                } else {
                    ContentUnavailableView {
                        Label("Kein Jahresplan", systemImage: "tablecells")
                    } description: {
                        Text("Importiere dein Budget-Excel im Tab «Excel» oder starte mit einem leeren Plan.")
                    } actions: {
                        Button("Plan für \(String(month.year)) erstellen") { createPlan(year: month.year) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(plan?.title ?? "Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { planMenu }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Ausgabe hinzufügen", systemImage: "minus.circle") { newItem = NewItemRequest(isIncome: false) }
                        Button("Einnahme hinzufügen", systemImage: "plus.circle") { newItem = NewItemRequest(isIncome: true) }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(plan == nil)
                }
            }
            .sheet(item: $editingItem) { item in
                if let plan = item.plan {
                    PlanItemEditor(item: item, plan: plan, isIncome: item.isIncome)
                }
            }
            .sheet(item: $newItem) { request in
                if let plan {
                    PlanItemEditor(item: nil, plan: plan, isIncome: request.isIncome)
                }
            }
            .alert("Plan bearbeiten", isPresented: $editingPlan) {
                TextField("Name", text: $nameDraft)
                TextField("Jahr", text: $yearDraft).keyboardType(.numberPad)
                Button("Sichern") { savePlanDetails() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Das Jahr bestimmt, für welche Monate der Plan in der Übersicht gilt.")
            }
            .confirmationDialog("Plan «\(plan?.name ?? "")» löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let plan {
                        context.delete(plan)
                        activePlan = ""
                    }
                }
            }
        }
    }

    // MARK: - Liste

    private func planList(_ plan: BudgetPlan) -> some View {
        let groups = Dictionary(grouping: plan.expenseItems, by: \.category)
            .map { CategoryGroup(category: $0.key, items: $0.value, total: $0.value.reduce(0) { $0 + value($1) }) }
            .sorted { $0.total > $1.total }
        let income = plan.incomeItems.reduce(0) { $0 + value($1) }
        let expenses = plan.expenseItems.reduce(0) { $0 + value($1) }

        return List {
            Section {
                Picker("Ansicht", selection: $showYearly) {
                    Text("Monat").tag(false)
                    Text("Ganzes Jahr").tag(true)
                }
                .pickerStyle(.segmented)
                if !showYearly { monthChips }
            }

            Section {
                LabeledContent("Einnahmen", value: income.currency(currency))
                LabeledContent("Ausgaben", value: expenses.currency(currency))
                LabeledContent {
                    Text((income - expenses).currency(currency))
                        .fontWeight(.semibold)
                        .foregroundStyle(income - expenses < 0 ? Color.red : Color.green)
                } label: {
                    Text("Überschuss / Negativ").fontWeight(.semibold)
                }
            } header: {
                Text(showYearly ? "Ganzes Jahr" : PlanSelection.monthNames[month.monthIndex])
            }

            ForEach(groups) { group in
                Section {
                    ForEach(group.items) { item in
                        Button { editingItem = item } label: { itemRow(item) }
                            .tint(Color.primary)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(group.items[index]) }
                    }
                } header: {
                    HStack {
                        Label(group.category, systemImage: CategoryStyle.icon(for: group.category))
                        Spacer()
                        Text(group.total.currencyShort(currency))
                    }
                }
            }

            Section {
                ForEach(plan.incomeItems) { item in
                    Button { editingItem = item } label: { itemRow(item) }
                        .tint(Color.primary)
                }
                .onDelete { offsets in
                    let items = plan.incomeItems
                    for index in offsets { context.delete(items[index]) }
                }
                Button("Einnahme hinzufügen", systemImage: "plus") { newItem = NewItemRequest(isIncome: true) }
            } header: {
                Text("Einnahmen")
            }
        }
    }

    private func itemRow(_ item: PlanItem) -> some View {
        let amount = value(item)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).lineLimit(2)
                if !showYearly {
                    Text("pro Jahr \(item.yearly.currencyShort(currency))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(amount.currency(currency))
                .monospacedDigit()
                .foregroundStyle(amount == 0 ? Color.secondary : item.isIncome ? Color.green : Color.primary)
        }
        .contentShape(Rectangle())
    }

    private var monthChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<12, id: \.self) { i in
                        let selected = i == month.monthIndex
                        Button(PlanSelection.shortMonthNames[i]) {
                            month = Calendar.current.date(from: DateComponents(year: month.year, month: i + 1, day: 1)) ?? month
                        }
                        .font(.footnote.weight(selected ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selected ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
            }
            .onAppear { proxy.scrollTo(month.monthIndex, anchor: .center) }
        }
    }

    // MARK: - Pläne verwalten

    private var planMenu: some View {
        Menu {
            Section("Pläne") {
                ForEach(plans) { p in
                    Button { select(p) } label: {
                        if p.persistentModelID == plan?.persistentModelID {
                            Label(p.title, systemImage: "checkmark")
                        } else {
                            Text(p.title)
                        }
                    }
                }
            }
            Section {
                Button("Neuer leerer Plan", systemImage: "doc.badge.plus") { createPlan(year: month.year) }
                if let plan {
                    let next = (plan.year > 0 ? plan.year : month.year) + 1
                    Button("Kopie für \(String(next)) erstellen", systemImage: "doc.on.doc") { duplicate(plan, year: next) }
                    Button("Name & Jahr ändern", systemImage: "pencil") {
                        nameDraft = plan.name
                        yearDraft = plan.year > 0 ? String(plan.year) : ""
                        editingPlan = true
                    }
                    Button("Plan löschen", systemImage: "trash", role: .destructive) { confirmDelete = true }
                }
            }
        } label: {
            Image(systemName: "square.stack.3d.up")
        }
    }

    private func select(_ p: BudgetPlan) {
        activePlan = p.name
        if p.year > 0 {
            month = Calendar.current.date(from: DateComponents(year: p.year, month: month.monthIndex + 1, day: 1)) ?? month
        }
    }

    private func uniqueName(_ base: String) -> String {
        var name = base
        var n = 2
        while plans.contains(where: { $0.name == name }) {
            name = "\(base) (\(n))"
            n += 1
        }
        return name
    }

    private func createPlan(year: Int) {
        let plan = BudgetPlan(name: uniqueName(String(year)), year: year,
                              sortOrder: (plans.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(plan)
        select(plan)
    }

    private func duplicate(_ source: BudgetPlan, year: Int) {
        let copy = BudgetPlan(name: uniqueName(String(year)), year: year,
                              sortOrder: (plans.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(copy)
        for item in source.items {
            let clone = PlanItem(title: item.title, category: item.category, isIncome: item.isIncome,
                                 amounts: item.amounts, sortOrder: item.sortOrder)
            context.insert(clone)
            clone.plan = copy
        }
        select(copy)
    }

    private func savePlanDetails() {
        guard let plan else { return }
        let name = nameDraft.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            plan.name = name
            activePlan = name
        }
        plan.year = Int(yearDraft.trimmingCharacters(in: .whitespaces)) ?? 0
        select(plan)
    }
}

// MARK: - Posten bearbeiten

struct PlanItemEditor: View {
    let item: PlanItem?
    let plan: BudgetPlan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("currency") private var currency = "CHF"

    @State private var title: String
    @State private var category: String
    @State private var categoryTouched: Bool
    @State private var isIncome: Bool
    @State private var sameEveryMonth: Bool
    @State private var monthlyText: String
    @State private var fromMonth: Int
    @State private var toMonth: Int
    @State private var texts: [String]
    @State private var yearlyText = ""

    init(item: PlanItem?, plan: BudgetPlan, isIncome: Bool) {
        self.item = item
        self.plan = plan
        let amounts = item?.amounts ?? Array(repeating: 0, count: 12)
        let used = amounts.indices.filter { amounts[$0] != 0 }
        let first = used.first ?? 0
        let last = used.last ?? 11
        let distinct = Set(used.map { (amounts[$0] * 100).rounded() })
        let same = distinct.count <= 1 && (used.isEmpty || used.count == last - first + 1)

        _title = State(initialValue: item?.title ?? "")
        _category = State(initialValue: item?.category ?? "")
        _categoryTouched = State(initialValue: item != nil)
        _isIncome = State(initialValue: item?.isIncome ?? isIncome)
        _sameEveryMonth = State(initialValue: same)
        _monthlyText = State(initialValue: used.first.map { Self.format(amounts[$0]) } ?? "")
        _fromMonth = State(initialValue: same ? first : 0)
        _toMonth = State(initialValue: same ? last : 11)
        _texts = State(initialValue: amounts.map { $0 == 0 ? "" : Self.format($0) })
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    private func parse(_ text: String) -> Double { BudgetImporter.parseAmount(text).map(abs) ?? 0 }

    private var amounts: [Double] {
        if sameEveryMonth {
            let value = parse(monthlyText)
            return (0..<12).map { $0 >= fromMonth && $0 <= toMonth ? value : 0 }
        }
        return texts.map(parse)
    }

    private var suggestions: [String] {
        let used = Set(plan.items.filter { $0.isIncome == isIncome }.map(\.category))
        return used.union(isIncome ? CategoryStyle.incomeDefaults : CategoryStyle.expenseDefaults).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bezeichnung, z. B. Krankenkasse", text: $title)
                    Picker("Art", selection: $isIncome) {
                        Text("Ausgabe").tag(false)
                        Text("Einnahme").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Kategorie") {
                    TextField("Kategorie", text: Binding(get: { category }, set: { category = $0; categoryTouched = true }))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(suggestions, id: \.self) { c in
                                Button {
                                    category = c
                                    categoryTouched = true
                                } label: {
                                    Label(c, systemImage: CategoryStyle.icon(for: c))
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(category == c ? CategoryStyle.color(for: c) : Color(.tertiarySystemFill), in: Capsule())
                                        .foregroundStyle(category == c ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Toggle("Jeden Monat gleich", isOn: $sameEveryMonth)
                    if sameEveryMonth {
                        HStack {
                            Text(currency).foregroundStyle(.secondary)
                            TextField("Betrag pro Monat", text: $monthlyText).keyboardType(.decimalPad)
                        }
                        Picker("Von", selection: $fromMonth) {
                            ForEach(0..<12, id: \.self) { Text(PlanSelection.monthNames[$0]).tag($0) }
                        }
                        Picker("Bis", selection: $toMonth) {
                            ForEach(0..<12, id: \.self) { Text(PlanSelection.monthNames[$0]).tag($0) }
                        }
                        HStack {
                            TextField("Jahresrechnung, z. B. 1126", text: $yearlyText).keyboardType(.decimalPad)
                            Button("÷ \(max(toMonth - fromMonth + 1, 1)) verteilen") {
                                let months = Double(max(toMonth - fromMonth + 1, 1))
                                monthlyText = Self.format((parse(yearlyText) / months * 100).rounded() / 100)
                                yearlyText = ""
                            }
                            .disabled(parse(yearlyText) <= 0)
                        }
                    } else {
                        ForEach(0..<12, id: \.self) { i in
                            HStack {
                                Text(PlanSelection.monthNames[i])
                                Spacer()
                                TextField("0", text: $texts[i])
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 140)
                            }
                        }
                    }
                } header: {
                    Text("Betrag")
                } footer: {
                    Text("Pro Jahr: \(amounts.reduce(0, +).currency(currency))")
                }

                if let item {
                    Section {
                        Button("Posten löschen", role: .destructive) {
                            context.delete(item)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? (isIncome ? "Neue Einnahme" : "Neue Ausgabe") : "Posten bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: title) { _, newTitle in
                if !categoryTouched || category.isEmpty {
                    category = CategoryStyle.autoCategory(for: newTitle, isIncome: isIncome)
                }
            }
            .onChange(of: sameEveryMonth) { _, same in
                if same {
                    monthlyText = texts.first { !$0.isEmpty } ?? monthlyText
                } else {
                    let current = amounts
                    texts = current.map { $0 == 0 ? "" : Self.format($0) }
                }
            }
            .onChange(of: fromMonth) { _, value in if toMonth < value { toMonth = value } }
            .onChange(of: toMonth) { _, value in if fromMonth > value { fromMonth = value } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespaces)
        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        let finalCategory = trimmedCategory.isEmpty ? CategoryStyle.autoCategory(for: name, isIncome: isIncome) : trimmedCategory
        if let item {
            item.title = name
            item.category = finalCategory
            item.isIncome = isIncome
            item.amounts = amounts
        } else {
            let newItem = PlanItem(title: name, category: finalCategory, isIncome: isIncome,
                                   amounts: amounts, sortOrder: plan.nextSortOrder)
            context.insert(newItem)
            newItem.plan = plan
        }
        dismiss()
    }
}
