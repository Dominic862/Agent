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
    @Query private var bookings: [Booking]
    @Query private var budgets: [CategoryBudget]
    @AppStorage("currency") private var currency = "CHF"
    @AppStorage("autoSaveExcel") private var autoSave = true

    @State private var showImporter = false
    @State private var pendingImport: ImportResult?
    @State private var share: ShareItem?
    @State private var message: String?
    @State private var confirmDeleteAll = false

    private let currencies = ["CHF", "EUR", "USD", "GBP"]

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
                    .disabled(bookings.isEmpty && budgets.isEmpty)
                    Button {
                        exportTemplate()
                    } label: {
                        Label("Leere Excel-Vorlage", systemImage: "doc.badge.plus")
                    }
                } header: {
                    Text("Excel")
                } footer: {
                    Text("Erkannt werden Spalten wie Datum, Beschreibung, Kategorie, Typ (Einnahme/Ausgabe) und Betrag – auch Bank-Exporte mit negativen Beträgen oder getrennten Soll/Haben-Spalten. Ein Blatt «Budgets» (Kategorie, Monatsbudget) wird ebenfalls übernommen.")
                }

                Section {
                    Toggle("Automatisch als Excel sichern", isOn: $autoSave)
                    if autoSave {
                        Button("Jetzt sichern") {
                            AutoSave.run(context: context)
                            message = "Gesichert unter «Dateien › Auf meinem iPhone › Budget › Budget.xlsx»."
                        }
                    }
                } header: {
                    Text("Speichern")
                } footer: {
                    Text("Deine Daten werden laufend in der App gespeichert. Zusätzlich legt die App beim Schliessen eine aktuelle «Budget.xlsx» in der Dateien-App ab – ideal als Backup oder zum Weiterbearbeiten am Computer.")
                }

                Section("Darstellung") {
                    Picker("Währung", selection: $currency) {
                        ForEach(currencies, id: \.self) { Text($0) }
                    }
                }

                Section {
                    LabeledContent("Buchungen", value: "\(bookings.count)")
                    LabeledContent("Budgets", value: "\(budgets.count)")
                    Button("Beispieldaten laden") {
                        SampleData.insert(into: context)
                        message = "Beispieldaten für die letzten sechs Monate wurden hinzugefügt."
                    }
                    Button("Alle Daten löschen", role: .destructive) {
                        confirmDeleteAll = true
                    }
                    .disabled(bookings.isEmpty && budgets.isEmpty)
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
                Button("Hinzufügen (Duplikate überspringen)") { apply(result, replace: false) }
                Button("Alle bisherigen Daten ersetzen", role: .destructive) { apply(result, replace: true) }
                Button("Abbrechen", role: .cancel) {}
            } message: { result in
                Text("Gefunden: \(result.summary).")
            }
            .confirmationDialog("Wirklich alle Buchungen und Budgets löschen?",
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

    // MARK: - Aktionen

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
                let parsed = try BudgetImporter.importFile(at: copy)
                if parsed.bookings.isEmpty {
                    message = "In der Datei wurden keine gültigen Buchungen gefunden."
                } else {
                    pendingImport = parsed
                }
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
            bookings.forEach { context.delete($0) }
            budgets.forEach { context.delete($0) }
        }

        // Mehrfach vorhandene, identische Buchungen (z. B. zwei Kaffees am selben Tag) werden mitgezählt
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

        var budgetCount = 0
        for (category, limit) in result.budgets {
            if !replace, let current = budgets.first(where: { $0.category == category }) {
                current.monthlyLimit = limit
            } else {
                context.insert(CategoryBudget(category: category, monthlyLimit: limit))
            }
            budgetCount += 1
        }

        try? context.save()
        var text = "\(added) Buchungen importiert"
        if duplicates > 0 { text += ", \(duplicates) Duplikate übersprungen" }
        if budgetCount > 0 { text += ", \(budgetCount) Budgets übernommen" }
        if result.skippedRows > 0 { text += ", \(result.skippedRows) Zeilen ohne gültiges Datum/Betrag ignoriert" }
        message = text + "."
    }

    private func exportAll() {
        do {
            share = ShareItem(url: try BudgetExporter.temporaryFile(bookings: bookings, budgets: budgets))
        } catch {
            message = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func exportTemplate() {
        do {
            let example = [
                Booking(date: Date(), title: "Lohn", category: "Lohn", amount: 6000, isIncome: true),
                Booking(date: Date(), title: "Miete", category: "Wohnen", amount: 1800, isIncome: false),
                Booking(date: Date(), title: "Wocheneinkauf", category: "Lebensmittel", amount: 120.50, isIncome: false),
            ]
            let budgets = [CategoryBudget(category: "Lebensmittel", monthlyLimit: 600),
                           CategoryBudget(category: "Restaurant", monthlyLimit: 250)]
            share = ShareItem(url: try BudgetExporter.temporaryFile(bookings: example, budgets: budgets,
                                                                     name: "Budget-Vorlage.xlsx"))
        } catch {
            message = "Vorlage konnte nicht erstellt werden: \(error.localizedDescription)"
        }
    }

    private func deleteAll() {
        bookings.forEach { context.delete($0) }
        budgets.forEach { context.delete($0) }
        try? context.save()
    }
}
