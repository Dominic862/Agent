import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("autoSaveExcel") private var autoSave = true
    @State private var month = Date().startOfMonth

    var body: some View {
        TabView {
            DashboardView(month: $month)
                .tabItem { Label("Übersicht", systemImage: "chart.pie.fill") }
            PlanView(month: $month)
                .tabItem { Label("Plan", systemImage: "tablecells") }
            BookingsView()
                .tabItem { Label("Buchungen", systemImage: "list.bullet.rectangle.fill") }
            InsightsView(month: $month)
                .tabItem { Label("Tipps", systemImage: "lightbulb.fill") }
            SettingsView()
                .tabItem { Label("Excel", systemImage: "square.and.arrow.up.on.square") }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && autoSave {
                AutoSave.run(context: context)
            }
        }
    }
}
