import SwiftUI

/// Kategorien, automatische Zuordnung von Posten (z. B. «KK Kind» → Krankenkasse), Icons und Farben.
enum CategoryStyle {
    enum Bucket: String, CaseIterable {
        case needs = "Fixkosten & Bedarf"
        case wants = "Flexibel"
        case savings = "Sparen & Vorsorge"

        /// Richtwerte der 50/30/20-Regel
        var target: Double {
            switch self {
            case .needs: 0.5
            case .wants: 0.3
            case .savings: 0.2
            }
        }

        var color: Color {
            switch self {
            case .needs: .blue
            case .wants: .orange
            case .savings: .green
            }
        }
    }

    private struct Rule {
        let category: String
        let icon: String
        let keywords: [String]
        let bucket: Bucket
    }

    // Reihenfolge ist wichtig: der erste Treffer gewinnt («Haushalt» vor «Haus», «Telefon (Haus…)» vor Wohnen).
    private static let rules: [Rule] = [
        Rule(category: "Sparen & Vorsorge", icon: "banknote.fill",
             keywords: ["saule", "sparen", "sparkonto", "ruckstellung", "reserve", "3a", "3b", "geldanlage", "invest", "etf"], bucket: .savings),
        Rule(category: "Schulden & Rückzahlungen", icon: "creditcard.fill",
             keywords: ["ruckzahl", "kredit", "leasing", "abzahl", "darlehen"], bucket: .needs),
        Rule(category: "Steuern", icon: "building.columns.fill", keywords: ["steuer"], bucket: .needs),
        Rule(category: "Krankenkasse", icon: "cross.case.fill",
             keywords: ["krankenkasse", "kk", "pramie", "franchise"], bucket: .needs),
        Rule(category: "Mobilität", icon: "car.fill",
             keywords: ["auto", "benzin", "zug", "nummernschild", "tof", "velo", "parkplatz", "sbb", "ov", "halbtax",
                        "vignette", "viniette", "garage", "transport", "tanken"], bucket: .needs),
        Rule(category: "Versicherungen", icon: "shield.fill",
             keywords: ["versicherung", "rega", "mobi", "haftpflicht", "hausrat", "gebaude"], bucket: .needs),
        Rule(category: "Kommunikation & Medien", icon: "antenna.radiowaves.left.and.right",
             keywords: ["telefon", "natel", "handy", "internet", "serafe", "netflix", "spotify", "amazon", "abo", "tv", "streaming"], bucket: .needs),
        Rule(category: "Lebensmittel", icon: "cart.fill",
             keywords: ["lebensmittel", "haushalt", "einkauf", "migros", "coop", "aldi", "lidl", "grocer"], bucket: .needs),
        Rule(category: "Wohnen", icon: "house.fill",
             keywords: ["miete", "wohn", "haus", "zins", "nebenkosten", "amorti", "ammorti", "strom", "heizung", "ol", "wasser",
                        "unterhalt", "salzanlage", "kaminfeger", "chamifeger", "hypothek"], bucket: .needs),
        Rule(category: "Haustiere", icon: "pawprint.fill", keywords: ["katze", "hund", "tier"], bucket: .needs),
        Rule(category: "Verpflegung", icon: "fork.knife",
             keywords: ["essen", "restaurant", "kantine", "mittag", "kaffee", "cafe", "take"], bucket: .wants),
        Rule(category: "Gesundheit & Pflege", icon: "heart.fill",
             keywords: ["gesundheit", "apotheke", "drogerie", "hygiene", "kosmetik", "coiffeur", "arzt", "zahn", "fitness", "sport", "brille"], bucket: .needs),
        Rule(category: "Kleidung", icon: "tshirt.fill", keywords: ["kleid", "schuh", "mode"], bucket: .wants),
        Rule(category: "Kinder", icon: "figure.and.child.holdinghands", keywords: ["kinder", "kita", "schule", "spielzeug"], bucket: .needs),
        Rule(category: "Bildung", icon: "book.fill", keywords: ["weiterbildung", "bildung", "kurs", "studium", "buch"], bucket: .wants),
        Rule(category: "Freizeit & Ferien", icon: "airplane",
             keywords: ["ferien", "urlaub", "reise", "freizeit", "hobby", "ausgang", "kino", "flug"], bucket: .wants),
        Rule(category: "Geschenke & Spenden", icon: "gift.fill",
             keywords: ["geschenk", "geburi", "geburtstag", "weihn", "spende"], bucket: .wants),
        Rule(category: "Shopping", icon: "bag.fill", keywords: ["shopping", "elektronik", "mobel"], bucket: .wants),
        Rule(category: "Persönlich", icon: "person.fill", keywords: ["tabak", "taschengeld", "personlich"], bucket: .wants),
    ]

    private static let incomeRules: [Rule] = [
        Rule(category: "Lohn", icon: "briefcase.fill", keywords: ["lohn", "gehalt", "salar", "salary", "einkommen"], bucket: .needs),
        Rule(category: "Zulagen", icon: "figure.2.and.child.holdinghands", keywords: ["zulage", "kinderzulage", "familienzulage"], bucket: .needs),
        Rule(category: "Nebeneinkommen", icon: "plus.circle.fill", keywords: ["neben", "bonus", "nebenjob"], bucket: .needs),
    ]

    static let expenseDefaults = rules.map(\.category) + ["Sonstiges"]
    static let incomeDefaults = incomeRules.map(\.category) + ["Sonstige Einnahmen"]

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_CH")).lowercased()
    }

    private static func matches(_ rule: Rule, _ text: String) -> Bool {
        let folded = fold(text)
        let words = Set(folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        return rule.keywords.contains { kw in
            kw.count <= 3 ? words.contains(kw) : folded.contains(kw)
        }
    }

    /// Schlägt eine Kategorie für einen Posten vor, z. B. «Säule 3a Dom» → Sparen & Vorsorge.
    static func autoCategory(for title: String, isIncome: Bool) -> String {
        if isIncome {
            return incomeRules.first { matches($0, title) }?.category ?? "Sonstige Einnahmen"
        }
        return rules.first { matches($0, title) }?.category ?? "Sonstiges"
    }

    private static func rule(for category: String) -> Rule? {
        (rules + incomeRules).first { $0.category == category }
            ?? (rules + incomeRules).first { matches($0, category) }
    }

    static func icon(for category: String) -> String {
        rule(for: category)?.icon ?? "tag.fill"
    }

    static func bucket(for category: String) -> Bucket {
        rule(for: category)?.bucket ?? .wants
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

    static func isHousing(_ category: String) -> Bool { rule(for: category)?.category == "Wohnen" }
}
