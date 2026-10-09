import Foundation
import SwiftData

/// Eine tatsächliche Einnahme oder Ausgabe (Ist). `amount` ist immer positiv, die Richtung steht in `isIncome`.
@Model
final class Booking {
    var date: Date = Date()
    var title: String = ""
    var category: String = "Sonstiges"
    var amount: Double = 0
    var isIncome: Bool = false
    var note: String = ""

    init(date: Date, title: String, category: String, amount: Double, isIncome: Bool, note: String = "") {
        self.date = date
        self.title = title
        self.category = category
        self.amount = amount
        self.isIncome = isIncome
        self.note = note
    }

    var signedAmount: Double { isIncome ? amount : -amount }
}
