import SwiftUI

/// Standardkategorien sowie Icon und Farbe pro Kategorie.
enum CategoryStyle {
    static let expenseDefaults = [
        "Wohnen", "Lebensmittel", "Restaurant", "Transport", "Versicherungen", "Gesundheit",
        "Freizeit", "Shopping", "Abos", "Reisen", "Steuern", "Sparen", "Sonstiges"
    ]
    static let incomeDefaults = ["Lohn", "Nebeneinkommen", "Sonstige Einnahmen"]

    private static let icons: [(keywords: [String], icon: String)] = [
        (["wohn", "miete", "nebenkosten", "strom", "haushalt"], "house.fill"),
        (["lebensmittel", "einkauf", "migros", "coop", "grocer", "supermarkt"], "cart.fill"),
        (["restaurant", "essen", "kaffee", "café", "cafe", "take"], "fork.knife"),
        (["transport", "auto", "benzin", "öv", "sbb", "mobil", "verkehr"], "car.fill"),
        (["versicher", "krankenkasse"], "shield.fill"),
        (["gesundheit", "arzt", "apotheke", "fitness", "sport"], "cross.case.fill"),
        (["freizeit", "hobby", "kino", "ausgang"], "gamecontroller.fill"),
        (["shopping", "kleider", "kleidung"], "bag.fill"),
        (["abo", "streaming", "handy", "internet", "telefon"], "repeat"),
        (["reise", "ferien", "urlaub"], "airplane"),
        (["steuer"], "building.columns.fill"),
        (["spar", "3a", "invest", "anlage"], "banknote.fill"),
        (["lohn", "gehalt", "salär", "einkommen", "bonus"], "briefcase.fill"),
        (["einnahme", "neben"], "plus.circle.fill"),
        (["geschenk", "spende"], "gift.fill"),
        (["bildung", "kurs", "schule", "buch"], "book.fill"),
    ]

    static func icon(for category: String) -> String {
        let c = category.lowercased()
        return icons.first { entry in entry.keywords.contains { c.contains($0) } }?.icon ?? "tag.fill"
    }

    private static let palette: [Color] = [
        .blue, .orange, .green, .purple, .pink, .teal, .indigo, .red, .yellow, .mint, .cyan, .brown
    ]

    /// Stabile Farbe (hashValue ist pro Start zufällig, darum eigene Prüfsumme).
    static func color(for category: String) -> Color {
        if let index = expenseDefaults.firstIndex(of: category) {
            return palette[index % palette.count]
        }
        let sum = category.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[sum % palette.count]
    }

    static func isHousing(_ category: String) -> Bool {
        let c = category.lowercased()
        return c.contains("wohn") || c.contains("miete")
    }
}
