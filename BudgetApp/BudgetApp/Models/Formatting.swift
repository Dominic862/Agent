import Foundation

extension Double {
    func currency(_ code: String) -> String {
        formatted(.currency(code: code).precision(.fractionLength(2)))
    }

    func currencyShort(_ code: String) -> String {
        formatted(.currency(code: code).precision(.fractionLength(0)))
    }

    var percent: String {
        formatted(.percent.precision(.fractionLength(0)))
    }
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.dateInterval(of: .month, for: self)?.start ?? self
    }

    func addingMonths(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    var monthTitle: String {
        formatted(.dateTime.month(.wide).year())
    }
}
