import Foundation
import SwiftData

/// Eine Einnahme oder Ausgabe. `amount` ist immer positiv, die Richtung steht in `isIncome`.
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

/// Monatsbudget für eine Ausgabenkategorie.
@Model
final class CategoryBudget {
    var category: String = ""
    var monthlyLimit: Double = 0

    init(category: String, monthlyLimit: Double) {
        self.category = category
        self.monthlyLimit = monthlyLimit
    }
}
