# Budget – iOS-App mit Excel-Anbindung

SwiftUI-App (iOS 17+) zum Verwalten deines Budgets. Grundlage ist das Budget-Excel mit einem Jahresplan pro Blatt (Posten × Monate). Die App liest es ein, zeigt ein Dashboard, macht Verbesserungsvorschläge und speichert alles wieder als Excel im selben Format.

## Funktionen

| Tab | Inhalt |
|---|---|
| **Übersicht** | Monat aus dem Jahresplan: Einnahmen, Ausgaben, Überschuss, Sparquote · Überschuss-Balken für alle 12 Monate · Ausgaben nach Kategorie · Aufteilung nach 50/30/20 · Soll/Ist, sobald Buchungen erfasst sind |
| **Plan** | Dein Excel als Liste: Posten nach Kategorie, Monats- oder Jahresansicht, Posten bearbeiten (gleicher Betrag pro Monat, Von–Bis, Jahresrechnung ÷ Monate oder jeder Monat einzeln), Varianten wie «2026 (2)», Kopie fürs nächste Jahr |
| **Buchungen** | Optionale Ist-Erfassung (manuell oder Bank-Export als CSV) |
| **Tipps** | Verbesserungsvorschläge mit geschätztem Potenzial |
| **Excel** | Import, Export & Teilen, Vorlage, Auto-Backup, Währung, Beispieldaten |

### Verbesserungsvorschläge
Aus dem Jahresplan:
- Monate mit **Defizit** und **zu wenig Puffer** (Überschuss unter 3 % des Einkommens) mit Vorschlägen aus den flexiblen Posten
- **Sparquote** (Sparen, Säule 3a/3b, Sparkonten, Rückstellungen) gegenüber 15–20 %
- **Krankenkasse** über 10 % des Einkommens (Franchise, Modell, Prämienverbilligung, Kündigung bis 30.11.)
- **Wohnkosten** über ⅓, **Telefon/Internet/Medien** über 150 pro Monat, **Fixkosten** über 65 %
- **Vergleich mit dem Vorjahresplan**: grösste Mehrkosten, tiefer budgetierte Steuern
- Hinweis auf ein separates **Rückstellungskonto** für jährliche Rechnungen

Aus den Buchungen (falls erfasst): Kategorien über Plan, Hochrechnung bis Monatsende, Abos/wiederkehrende Zahlungen, Kleinbeträge.

### Speichern
- Alle Daten werden lokal mit **SwiftData** gespeichert.
- Mit «Automatisch als Excel sichern» legt die App beim Schliessen `Budget.xlsx` in **Dateien › Auf meinem iPhone › Budget** ab.
- «Als Excel exportieren & teilen» → In Dateien/iCloud sichern, per Mail senden, AirDrop …

## Excel-Format

Die App liest das Format des bestehenden Budget-Excels (siehe [`Vorlage/Budget-Vorlage.xlsx`](Vorlage/Budget-Vorlage.xlsx)):

**Ein Blatt pro Jahr** (Blattname = Jahr, z. B. `2026` oder `2026 (2)`):

| | Budget | Kategorie *(optional)* | Januar | … | Dezember | pro Jahr |
|---|---|---|---|---|---|---|
| | Wohnungsmiete | | 1950 | … | 1950 | =SUMME |
| | Krankenkasse Partner | | 480 | … | 480 | =SUMME |
| | *Total-Zeile* | | | | | |
| | Lohn | | 7800 | … | 7800 | |
| | Kinderzulage | | 215 | … | 215 | |
| | Überschuss/Negativ? | | | | | |

- Erkannt wird die Kopfzeile mit den Monaten Januar–Dezember; die Posten stehen links davon.
- Alles nach der Total-Zeile bis «Überschuss» gilt als Einnahme. Blöcke weiter unten (z. B. «Einnahmen»/«Ausgaben» zur Ist-Erfassung) werden ignoriert.
- Formeln wie `=1126/12` werden mit ihrem berechneten Wert übernommen.
- Die Summe wird mit der Total-Zeile des Excels abgeglichen. Fehlt dort ein Posten (z. B. eine Sparrate, die über ein anderes Konto läuft), lässt die App ihn ebenfalls weg und meldet das.
- Kategorien werden automatisch vergeben (z. B. «KK Kind» → Krankenkasse, «Säule 3b» → Sparen & Vorsorge) und sind pro Posten änderbar.
- Ein Blatt **«Transaktionen»** (Datum, Beschreibung, Kategorie, Typ, Betrag) wird als Ist-Buchungen gelesen; Bank-Exporte als CSV ebenso.

Der Export schreibt dasselbe Layout mit Summenformeln für Jahr, Total und Überschuss – du kannst also im Excel weiterarbeiten und wieder importieren («Hinzufügen / aktualisieren» ersetzt Pläne mit gleichem Namen).

## Projekt öffnen

Das Xcode-Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt:

```bash
brew install xcodegen
cd BudgetApp
xcodegen generate
open BudgetApp.xcodeproj
```

Dann in Xcode unter *Signing & Capabilities* dein Team wählen und auf dem iPhone oder im Simulator starten. Abhängigkeit: [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (wird automatisch per Swift Package Manager geladen) – zum Lesen/Schreiben der .xlsx-Container.

Zum Ausprobieren: Tab **Excel › Excel / CSV importieren** und das eigene Budget-Excel wählen – oder **Beispieldaten laden**.

## Struktur

```
BudgetApp/
├── project.yml                 XcodeGen-Projektdefinition
├── Config/Info.plist           Dateifreigabe für die «Dateien»-App
├── Vorlage/Budget-Vorlage.xlsx Excel-Vorlage
└── BudgetApp/
    ├── BudgetApp.swift         App-Einstieg, SwiftData-Container
    ├── Models/                 BudgetPlan/PlanItem (Soll), Booking (Ist), Kategorien-Regeln, Formatierung
    ├── Services/
    │   ├── XLSXReader.swift    .xlsx- und CSV-Leser
    │   ├── XLSXWriter.swift    .xlsx-Schreiber (Formate, fixierte Kopfzeile)
    │   ├── BudgetImporter.swift Jahresplan- und Buchungs-Erkennung
    │   ├── BudgetExporter.swift Export im Plan-Layout + Auto-Backup
    │   ├── Analytics.swift     Monatssummen, Trends, Abo-Erkennung
    │   ├── InsightEngine.swift Verbesserungsvorschläge
    │   └── SampleData.swift    Beispieldaten
    └── Views/                  Übersicht, Plan, Buchungen, Tipps, Excel
```
