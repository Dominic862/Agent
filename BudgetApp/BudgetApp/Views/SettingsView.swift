import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    static let xlsx = UTType(filenameExtension: "xlsx") ?? .spreadsheet
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BudgetPlan.sortOrder) private var plans: [BudgetPlan]
    @Query private var bookings: [Booking]
    @AppStorage("currency") private var currency = "CHF"
    @AppStorage("autoSaveExcel") private var autoSave = true
    @AppStorage("activePlan") private var activePlan = ""

    @State private var showImporter = false
    @State private var pendingImport: ImportResult?
    @State private var share: ShareItem?
    @State private var message: String?
    @State private var confirmDeleteAll = false

    private let currencies = ["CHF", "EUR", "USD", "GBP"]
    private var isEmpty: Bool { plans.isEmpty && bookings.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Excel / CSV importieren", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        exportAll()
                    } label: {
                        Label("Als Excel exportieren & teilen", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isEmpty)
                    Button {
                        exportTemplate()
                    } label: {
                        Label("Excel-Vorlage", systemImage: "doc.badge.plus")
                    }
                } header: {
                    Text("Excel")
                } footer: {
                    Text("Jahrespläne werden erkannt, wenn die Monate Januar–Dezember als Spalten und die Posten als Zeilen stehen (ein Blatt pro Jahr, Einnahmen wie «Lohn» unter dem Total). Buchungslisten und Bank-Exporte brauchen die Spalten Datum und Betrag. Der Export schreibt wieder dieses Format – mit Summenformeln.")
                }

                Section {
                    Toggle("Automatisch als Excel sichern", isOn: $autoSave)
                    if autoSave {
                        Button("Jetzt sichern") {
                            AutoSave.run(context: context)
                            message = "Gesichert unter «Dateien › Auf meinem iPhone › Budget › Budget.xlsx»."
                        }
                        .disabled(isEmpty)
                    }
                } header: {
                    Text("Speichern")
                } footer: {
                    Text("Alle Daten werden in der App gespeichert. Zusätzlich legt die App beim Schliessen eine aktuelle «Budget.xlsx» in der Dateien-App ab – als Backup oder zum Weiterbearbeiten am Computer.")
                }

                Section("Darstellung") {
                    Picker("Währung", selection: $currency) {
                        ForEach(currencies, id: \.self) { Text($0) }
                    }
                }

                Section {
                    LabeledContent("Jahrespläne", value: "\(plans.count)")
                    LabeledContent("Posten", value: "\(plans.reduce(0) { $0 + $1.items.count })")
                    LabeledContent("Buchungen", value: "\(bookings.count)")
                    Button("Beispieldaten laden") {
                        SampleData.insert(into: context)
                        message = "Ein Beispielplan und Buchungen der letzten drei Monate wurden hinzugefügt."
                    }
                    Button("Alle Daten löschen", role: .destructive) {
                        confirmDeleteAll = true
                    }
                    .disabled(isEmpty)
                } header: {
                    Text("Daten")
                }
            }
            .navigationTitle("Excel & Daten")
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.xlsx, .commaSeparatedText, .plainText]) { result in
                handleImport(result)
            }
            .confirmationDialog("Import", isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            ), titleVisibility: .visible, presenting: pendingImport) { result in
                Button("Hinzufügen / aktualisieren") { apply(result, replace: false) }
                Button("Alle bisherigen Daten ersetzen", role: .destructive) { apply(result, replace: true) }
                Button("Abbrechen", role: .cancel) {}
            } message: { result in
                Text("Gefunden: \(result.summary). Pläne mit gleichem Namen werden beim Hinzufügen ersetzt, doppelte Buchungen übersprungen.")
            }
            .confirmationDialog("Wirklich alle Pläne und Buchungen löschen?",
                                isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Alles löschen", role: .destructive) { deleteAll() }
            } message: {
                Text("Exportiere vorher ein Backup, falls du die Daten noch brauchst.")
            }
            .alert("Hinweis", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(message ?? "")
            }
            .sheet(item: $share) { item in
                ActivityView(items: [item.url])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Import

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                // Kopie anlegen, damit iCloud-/Fremd-Dateien sicher lesbar sind
                let copy = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + "." + url.pathExtension)
                try FileManager.default.copyItem(at: url, to: copy)
                defer { try? FileManager.default.removeItem(at: copy) }
                pendingImport = try BudgetImporter.importFile(at: copy)
            } catch {
                message = error.localizedDescription
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func key(date: Date, title: String, amount: Double, isIncome: Bool) -> String {
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        return "\(day)|\(title.lowercased())|\(String(format: "%.2f", amount))|\(isIncome)"
    }

    private func apply(_ result: ImportResult, replace: Bool) {
        if replace {
            plans.forEach { context.delete($0) }
            bookings.forEach { context.delete($0) }
        }

        // Pläne: gleicher Name → ersetzen
        var order = replace ? 0 : (plans.map(\.sortOrder).max() ?? -1) + 1
        for parsed in result.plans {
            var sortOrder = order
            if !replace, let existing = plans.first(where: { $0.name == parsed.name }) {
                sortOrder = existing.sortOrder
                context.delete(existing)
            } else {
                order += 1
            }
            let plan = BudgetPlan(name: parsed.name, year: parsed.year, sortOrder: sortOrder)
            context.insert(plan)
            for (index, p) in parsed.items.enumerated() {
                let item = PlanItem(title: p.title, category: p.category, isIncome: p.isIncome,
                                    amounts: p.amounts, sortOrder: index)
                context.insert(item)
                item.plan = plan
            }
        }

        // Buchungen: identische mehrfach vorhandene Einträge (z. B. zwei Kaffees am selben Tag) werden mitgezählt
        var existing: [String: Int] = [:]
        if !replace {
            for b in bookings {
                existing[key(date: b.date, title: b.title, amount: b.amount, isIncome: b.isIncome), default: 0] += 1
            }
        }
        var added = 0
        var duplicates = 0
        for p in result.bookings {
            let k = key(date: p.date, title: p.title, amount: p.amount, isIncome: p.isIncome)
            if let count = existing[k], count > 0 {
                existing[k] = count - 1
                duplicates += 1
                continue
            }
            context.insert(Booking(date: p.date, title: p.title, category: p.category,
                                   amount: p.amount, isIncome: p.isIncome, note: p.note))
            added += 1
        }
        try? context.save()

        // Plan des aktuellen Jahres aktiv setzen (bevorzugt das Blatt, das genau so heisst)
        let year = Date().year
        if let current = result.plans.first(where: { $0.name == String(year) }) ?? result.plans.first(where: { $0.year == year }) {
            activePlan = current.name
        }

        var lines: [String] = []
        if !result.plans.isEmpty {
            lines.append("\(result.plans.count) Jahrespläne mit \(result.plans.reduce(0) { $0 + $1.items.count }) Posten importiert.")
            let unknown = result.plans.filter { $0.year == 0 }.map(\.name)
            if !unknown.isEmpty {
                lines.append("Ohne Jahr: \(unknown.joined(separator: ", ")) – Jahr im Tab «Plan» über das Stapel-Menü setzen.")
            }
        }
        if !result.bookings.isEmpty {
            lines.append("\(added) Buchungen importiert" + (duplicates > 0 ? ", \(duplicates) Duplikate übersprungen." : "."))
        }
        if result.skippedRows > 0 { lines.append("\(result.skippedRows) Zeilen ohne gültiges Datum/Betrag ignoriert.") }
        lines += result.notes
        message = lines.joined(separator: "\n\n")
    }

    // MARK: - Export

    private func exportAll() {
        do {
            share = ShareItem(url: try BudgetExporter.temporaryFile(plans: plans, bookings: bookings))
        } catch {
            message = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Vorlage aus einem temporären In-Memory-Speicher, damit die eigenen Daten unberührt bleiben.
    private func exportTemplate() {
        do {
            let container = try ModelContainer(for: BudgetPlan.self, PlanItem.self, Booking.self,
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let scratch = ModelContext(container)
            let plan = SampleData.insertPlan(into: scratch, year: Date().year)
            share = ShareItem(url: try BudgetExporter.temporaryFile(plans: [plan], bookings: [], name: "Budget-Vorlage.xlsx"))
        } catch {
            message = "Vorlage konnte nicht erstellt werden: \(error.localizedDescription)"
        }
    }

    private func deleteAll() {
        plans.forEach { context.delete($0) }
        bookings.forEach { context.delete($0) }
        try? context.save()
        activePlan = ""
    }
}
