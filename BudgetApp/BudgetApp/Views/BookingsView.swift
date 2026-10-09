import SwiftUI
import SwiftData

struct BookingsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "Alle", expenses = "Ausgaben", income = "Einnahmen"
        var id: Self { self }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \Booking.date, order: .reverse) private var bookings: [Booking]
    @AppStorage("currency") private var currency = "CHF"
    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var editing: Booking?
    @State private var showingNew = false

    private var filtered: [Booking] {
        bookings.filter { b in
            switch filter {
            case .all: break
            case .expenses: if b.isIncome { return false }
            case .income: if !b.isIncome { return false }
            }
            guard !search.isEmpty else { return true }
            return b.title.localizedCaseInsensitiveContains(search)
                || b.category.localizedCaseInsensitiveContains(search)
                || b.note.localizedCaseInsensitiveContains(search)
        }
    }

    private struct MonthSection: Identifiable {
        let month: Date
        let items: [Booking]
        var id: Date { month }
    }

    private var sections: [MonthSection] {
        let groups = Dictionary(grouping: filtered) { $0.date.startOfMonth }
        return groups.keys.sorted(by: >).map { MonthSection(month: $0, items: groups[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                ForEach(sections) { section in
                    Section {
                        ForEach(section.items) { booking in
                            Button { editing = booking } label: {
                                BookingRow(booking: booking, currency: currency)
                            }
                            .tint(Color.primary)
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(section.items[index]) }
                        }
                    } header: {
                        HStack {
                            Text(section.month.monthTitle)
                            Spacer()
                            let net = section.items.reduce(0) { $0 + $1.signedAmount }
                            Text(net.currency(currency))
                                .foregroundStyle(net >= 0 ? Color.green : Color.red)
                        }
                    }
                }
            }
            .overlay {
                if bookings.isEmpty {
                    ContentUnavailableView("Noch keine Buchungen", systemImage: "list.bullet.rectangle",
                                           description: Text("Tippe auf + oder importiere ein Excel im Tab «Excel»."))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .searchable(text: $search, prompt: "Beschreibung, Kategorie, Notiz")
            .navigationTitle("Buchungen")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { BookingEditor(booking: $0) }
            .sheet(isPresented: $showingNew) { BookingEditor(booking: nil) }
        }
    }
}

struct BookingRow: View {
    let booking: Booking
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: booking.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.title).font(.body).lineLimit(1)
                Text("\(booking.category) · \(booking.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(booking.signedAmount.currency(currency))
                .font(.body.monospacedDigit())
                .foregroundStyle(booking.isIncome ? Color.green : Color.primary)
        }
        .contentShape(Rectangle())
    }
}

struct BookingEditor: View {
    let booking: Booking?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allBookings: [Booking]
    @AppStorage("currency") private var currency = "CHF"

    @State private var isIncome: Bool
    @State private var title: String
    @State private var amountText: String
    @State private var date: Date
    @State private var category: String
    @State private var note: String

    init(booking: Booking?) {
        self.booking = booking
        _isIncome = State(initialValue: booking?.isIncome ?? false)
        _title = State(initialValue: booking?.title ?? "")
        _amountText = State(initialValue: booking.map { String(format: "%.2f", $0.amount) } ?? "")
        _date = State(initialValue: booking?.date ?? Date())
        _category = State(initialValue: booking?.category ?? "")
        _note = State(initialValue: booking?.note ?? "")
    }

    private var amount: Double? { BudgetImporter.parseAmount(amountText).map(abs) }

    private var suggestions: [String] {
        let used = Set(allBookings.filter { $0.isIncome == isIncome }.map(\.category))
        let defaults = isIncome ? CategoryStyle.incomeDefaults : CategoryStyle.expenseDefaults
        return used.union(defaults).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Art", selection: $isIncome) {
                    Text("Ausgabe").tag(false)
                    Text("Einnahme").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    HStack {
                        Text(currency).foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.monospacedDigit())
                    }
                    TextField("Beschreibung (z. B. Migros)", text: $title)
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                }

                Section("Kategorie") {
                    TextField("Kategorie", text: $category)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(suggestions, id: \.self) { c in
                                Button { category = c } label: {
                                    Label(c, systemImage: CategoryStyle.icon(for: c))
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            (category == c ? CategoryStyle.color(for: c) : Color(.tertiarySystemFill)),
                                            in: Capsule())
                                        .foregroundStyle(category == c ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Notiz") {
                    TextField("Optional", text: $note, axis: .vertical)
                }

                if let booking {
                    Section {
                        Button("Buchung löschen", role: .destructive) {
                            context.delete(booking)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(booking == nil ? "Neue Buchung" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled((amount ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        guard let amount, amount > 0 else { return }
        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        let finalCategory = trimmedCategory.isEmpty ? (isIncome ? "Sonstige Einnahmen" : "Sonstiges") : trimmedCategory
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let finalTitle = trimmedTitle.isEmpty ? finalCategory : trimmedTitle
        let day = Calendar.current.startOfDay(for: date)

        if let booking {
            booking.isIncome = isIncome
            booking.title = finalTitle
            booking.amount = amount
            booking.date = day
            booking.category = finalCategory
            booking.note = note
        } else {
            context.insert(Booking(date: day, title: finalTitle, category: finalCategory,
                                   amount: amount, isIncome: isIncome, note: note))
        }
        dismiss()
    }
}
