import SwiftUI
import SwiftData

@main
struct BudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [BudgetPlan.self, PlanItem.self, Booking.self])
    }
}
