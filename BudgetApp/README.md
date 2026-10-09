# Budget – iOS-App mit Excel-Anbindung

SwiftUI-App (iOS 17+) zum Verwalten deines Budgets. Daten kommen aus einem Excel, werden in der App gespeichert und lassen sich jederzeit wieder als Excel sichern.

## Funktionen

| Tab | Inhalt |
|---|---|
| **Übersicht** | Dashboard pro Monat: Einnahmen, Ausgaben, Saldo, Sparquote, Donut-Chart nach Kategorie, Budget-Fortschritt, 6-Monats-Verlauf, Top-Tipps |
| **Buchungen** | Liste nach Monaten, Suche, Filter, Erfassen/Bearbeiten/Löschen (Wischen) |
| **Budgets** | Monatsbudget pro Kategorie mit Fortschrittsbalken; Vorschläge aus deinem Ø der letzten 3 Monate |
| **Tipps** | Verbesserungsvorschläge mit geschätztem Sparpotenzial |
| **Excel** | Import (.xlsx / .csv), Export & Teilen, leere Vorlage, Auto-Backup, Währung, Beispieldaten |

### Verbesserungsvorschläge (Tipps)
- Budget überschritten bzw. **auf Kurs zur Überschreitung** (Hochrechnung mit Tagesbetrag für den Rest des Monats)
- Sparquote nach der **50/30/20-Regel** (Defizit-Warnung, Lücke zum 20-%-Ziel)
- Kategorien deutlich **über dem Durchschnitt** der Vormonate
- Erkennung **wiederkehrender Zahlungen/Abos** mit Jahreskosten
- **Kleinbeträge**, die sich summieren (z. B. Kaffee)
- Wohnkosten > ⅓ des Einkommens, eine Kategorie dominiert die Ausgaben
- Fehlende Budgets mit konkretem Vorschlag

### Speichern
- Alle Daten werden lokal mit **SwiftData** gespeichert.
- Mit «Automatisch als Excel sichern» legt die App beim Schliessen `Budget.xlsx` in **Dateien › Auf meinem iPhone › Budget** ab.
- «Als Excel exportieren & teilen» → In Dateien/iCloud sichern, per Mail senden, AirDrop …

## Excel-Format

Siehe [`Vorlage/Budget-Vorlage.xlsx`](Vorlage/Budget-Vorlage.xlsx).

**Blatt «Transaktionen»**

| Datum | Beschreibung | Kategorie | Typ | Betrag | Notiz |
|---|---|---|---|---|---|
| 01.10.2026 | Miete | Wohnen | Ausgabe | 1850.00 | |
| 25.10.2026 | Lohn | Lohn | Einnahme | 6400.00 | |

**Blatt «Budgets»**: `Kategorie | Monatsbudget`

Der Import ist tolerant: Spaltennamen werden auch auf Englisch oder in Bank-Varianten erkannt (`Date`, `Buchungstext`, `Amount`, `Soll/Haben`, `Belastung/Gutschrift` …), Beträge wie `1'234.50`, `1.234,50` oder `-12.00`, Datumsangaben als Excel-Datum oder Text. Ohne Typ-Spalte gelten negative Beträge als Ausgaben. Beim Import wählst du «Hinzufügen» (Duplikate werden übersprungen) oder «Ersetzen».

## Projekt öffnen

Das Xcode-Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt:

```bash
brew install xcodegen
cd BudgetApp
xcodegen generate
open BudgetApp.xcodeproj
```

Dann in Xcode unter *Signing & Capabilities* dein Team wählen und auf dem iPhone oder im Simulator starten. Abhängigkeit: [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (wird automatisch per Swift Package Manager geladen) – zum Lesen/Schreiben der .xlsx-Container.

Zum Ausprobieren: Tab **Excel › Beispieldaten laden**.

## Struktur

```
BudgetApp/
├── project.yml                 XcodeGen-Projektdefinition
├── Config/Info.plist           Dateifreigabe für die «Dateien»-App
├── Vorlage/Budget-Vorlage.xlsx Excel-Vorlage
└── BudgetApp/
    ├── BudgetApp.swift         App-Einstieg, SwiftData-Container
    ├── Models/                 Booking, CategoryBudget, Kategorien-Icons/Farben, Formatierung
    ├── Services/
    │   ├── XLSXReader.swift    .xlsx- und CSV-Leser
    │   ├── XLSXWriter.swift    .xlsx-Schreiber (Formate, fixierte Kopfzeile)
    │   ├── BudgetImporter.swift Spaltenerkennung & Werte-Parsing
    │   ├── BudgetExporter.swift Export + Auto-Backup
    │   ├── Analytics.swift     Monatssummen, Trends, Abo-Erkennung, Budgetvorschläge
    │   ├── InsightEngine.swift Verbesserungsvorschläge
    │   └── SampleData.swift    Beispieldaten
    └── Views/                  Dashboard, Buchungen, Budgets, Tipps, Excel
```
