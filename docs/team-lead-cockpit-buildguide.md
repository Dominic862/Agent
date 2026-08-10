# Team Lead Cockpit – Baudokumentation

Model-driven Power App auf Dataverse, um als Team Leiter im Consulting den Überblick über Auslastung, Weiterentwicklung, Projekte, Wünsche, Lessons Learned sowie Halbjahres-/Jahresendgespräche (inkl. Beförderungen) zu behalten.

Diese App wird in Power Apps Studio (make.powerapps.com) gebaut, nicht als Git-Code. Dieses Dokument ist die Spezifikation/Referenz, die du beim Bauen abarbeitest — jeder Abschnitt ist copy-paste-fähig für die Tabellen-/Spaltennamen und die Power Apps Copilot-Prompts.

**Ziel-Environment:** `https://make.powerapps.com/environments/13d81629-1580-efa4-8815-5b503fdfbb4d/home`
**Solution:** `https://make.powerapps.com/environments/13d81629-1580-efa4-8815-5b503fdfbb4d/solutions/528705b1-ae94-f111-8075-7c1e52fb87aa`

## 0. Solution & Publisher

1. make.powerapps.com → obige Environment (`13d81629-1580-efa4-8815-5b503fdfbb4d`) auswählen → **Solutions** → **New solution**
2. Solution-Name: `Team Lead Cockpit`
3. Publisher: neuen Publisher anlegen, z. B. Name `Team Lead Cockpit Publisher`, **Prefix**: `tlc`
4. Nicht in der Default-Solution arbeiten — alle folgenden Tabellen/Objekte innerhalb dieser Solution anlegen.
5. ✅ Solution angelegt — weiter mit Abschnitt 1 (Tabellen)

## 1. Tabellen

### 1.1 Team Member (`tlc_teammember`)
| Spalte | Typ | Hinweis |
|---|---|---|
| Name | Text (Primärspalte) | Vor-/Nachname |
| Rolle/Titel | Text | z. B. Consultant, Senior Consultant |
| Level/Seniorität | Choice | z. B. Junior, Consultant, Senior, Manager, Principal (frei an eure Karrierestufen anpassen) |
| Start im Team | Datum | |
| Status | Choice | Aktiv / Inaktiv |
| E-Mail | Text | |

### 1.2 Project (`tlc_project`)
| Spalte | Typ | Hinweis |
|---|---|---|
| Projektname | Text (Primärspalte) | |
| Kunde | Text | |
| Start | Datum | |
| Ende | Datum | |
| Status | Choice | Aktiv / Pausiert / Abgeschlossen |
| Projektleiter | Lookup → Team Member | |

### 1.3 Assignment (`tlc_assignment`) — Auslastung
Manuelle N:N-Zwischentabelle zwischen Team Member und Project (Standard-Dataverse-N:N kann keine Zusatzfelder wie Auslastung % speichern).

| Spalte | Typ | Hinweis |
|---|---|---|
| Name | Text (Primärspalte, autogeneriert reicht) | |
| Team Member | Lookup → Team Member | |
| Project | Lookup → Project | |
| Auslastung % | Zahl (0–100) | |
| Zeitraum von | Datum | |
| Zeitraum bis | Datum | |
| Rolle im Projekt | Text | |
| Billable | Ja/Nein | |

### 1.4 Development Item (`tlc_developmentitem`) — Weiterentwicklung/Schulung
| Spalte | Typ | Hinweis |
|---|---|---|
| Titel | Text (Primärspalte) | |
| Team Member | Lookup → Team Member | |
| Typ | Choice | Schulung / Zertifizierung / Konferenz / Coaching |
| Status | Choice | Geplant / Laufend / Abgeschlossen |
| Datum | Datum | |
| Notiz | Mehrzeiliger Text | |

### 1.5 Wish (`tlc_wish`) — Wünsche der Mitarbeitenden
| Spalte | Typ | Hinweis |
|---|---|---|
| Titel | Text (Primärspalte) | Kurzbeschreibung |
| Team Member | Lookup → Team Member | |
| Kategorie | Choice | Projekt / Rolle / Skill / Standort / Sonstiges |
| Beschreibung | Mehrzeiliger Text | |
| Priorität | Choice | Niedrig / Mittel / Hoch |
| Status | Choice | Offen / In Arbeit / Erfüllt |
| Erfasst am | Datum | |

### 1.6 Retro Note (`tlc_retronote`) — Was nicht gut lief
| Spalte | Typ | Hinweis |
|---|---|---|
| Titel | Text (Primärspalte) | |
| Team Member | Lookup → Team Member (optional) | |
| Project | Lookup → Project (optional) | |
| Kategorie | Choice | frei definierbar, z. B. Kommunikation / Scope / Ressourcen / Prozess |
| Beschreibung | Mehrzeiliger Text | |
| Ursache | Mehrzeiliger Text | |
| Massnahme | Mehrzeiliger Text | |
| Status | Choice | Offen / Erledigt |
| Datum | Datum | |

### 1.7 Conversation (`tlc_conversation`) — Gespräche & Beförderungen
| Spalte | Typ | Hinweis |
|---|---|---|
| Titel | Text (Primärspalte, autogeneriert reicht) | |
| Team Member | Lookup → Team Member | |
| Typ | Choice | 1:1 / **Halbjahresgespräch** / Jahresendgespräch / Zwischenfeedback / Onboarding / Sonstiges |
| Datum | Datum | |
| Zusammenfassung | Mehrzeiliger Text | |
| Ziele/Action Items | Mehrzeiliger Text | |
| Nächstes Gespräch geplant am | Datum | |
| Beförderungsrelevant | Ja/Nein | |
| Aktuelles Level | Choice (gleiche Optionen wie Team Member.Level) | |
| Neues Level | Choice (gleiche Optionen wie Team Member.Level) | nur bei Beförderungsrelevant = Ja |

**Beförderungslogik:** Halbjahres- und Jahresendgespräch sind die zwei offiziellen Review-Zeitpunkte pro Jahr. Eine Beförderung wird als Teil des jeweiligen Gesprächs erfasst (Aktuelles Level → Neues Level), nicht in einer eigenen Tabelle. `Team Member.Level/Seniorität` bleibt der aktuelle Stand und wird nach einer Beförderung nachgezogen (MVP: manuell; Phase 2: automatisiert, siehe Abschnitt 5).

### Aktivitäten aktivieren
Auf Team Member, Conversation, Wish, Retro Note: Tabelleneinstellungen → **Aktivitäten aktivieren** (Task, Notiz) für Follow-ups/Erinnerungen direkt am Datensatz.

## 2. Copilot-Prompt zum Schnellstart (Power Apps Studio → Tabellen mit Copilot erstellen)

Power Apps Studio bietet "Tabellen mit Copilot beschreiben" beim Anlegen neuer Tabellen. Folgenden Text als Ausgangsbasis einfügen und danach gegen die obigen Spaltenlisten prüfen/korrigieren (Copilot generiert eine erste Näherung, keine 1:1-Kopie der Tabelle oben):

```
Ich brauche Tabellen für ein Team-Management-Tool für einen Consulting-Team-Leiter:
- Team Member: Name, Rolle, Level/Seniorität, Startdatum im Team, Status, E-Mail
- Project: Projektname, Kunde, Start, Ende, Status, Projektleiter (Bezug zu Team Member)
- Assignment: Bezug zu Team Member und Project, Auslastung in Prozent, Zeitraum von/bis, Rolle im Projekt, Billable
- Development Item: Bezug zu Team Member, Titel, Typ (Schulung/Zertifizierung/Konferenz/Coaching), Status, Datum, Notiz
- Wish: Bezug zu Team Member, Titel, Kategorie, Beschreibung, Priorität, Status, Erfasst am
- Retro Note: optionaler Bezug zu Team Member und Project, Titel, Kategorie, Beschreibung, Ursache, Massnahme, Status, Datum
- Conversation: Bezug zu Team Member, Typ (1:1/Halbjahresgespräch/Jahresendgespräch/Zwischenfeedback/Onboarding/Sonstiges), Datum, Zusammenfassung, Ziele, nächstes Gespräch geplant am, Beförderungsrelevant (Ja/Nein), aktuelles Level, neues Level
```

## 3. Sicherheitsrolle

1. Power Platform Admin Center → Environment → **Security roles** → Rolle **"Basic User"** duplizieren, umbenennen zu **"Team Lead"**
2. Auf allen 7 Tabellen (inkl. Standardtabellen, die referenziert werden) volle Rechte (Create/Read/Write/Delete/Append/Append To) auf Business-Unit-Ebene setzen
3. **Wichtig:** Conversation und Wish nur dieser Rolle geben — nicht an Standardrollen wie "Basic User" durchreichen, da personalsensible Inhalte
4. Rolle dir selbst zuweisen

## 4. Views & Dashboard

**Views:**
- Aktuelle Auslastung (Assignment, gefiltert auf laufenden Zeitraum, gruppiert nach Team Member)
- Offene Wünsche (Wish, Status = Offen)
- Anstehende/überfällige Review-Gespräche (Conversation, Typ = Halbjahresgespräch ODER Jahresendgespräch, Datum vor mehr als ~5 Monaten)
- Beförderungen dieses Jahr (Conversation, Beförderungsrelevant = Ja)
- Offene Retro-Punkte (Retro Note, Status = Offen)

**Dashboard "Team Übersicht":**
- Balkendiagramm: Auslastung % je Team Member (aktueller Zeitraum)
- Kreisdiagramm: Projekte nach Status
- Zähler/Liste: offene Wünsche, offene Retro-Punkte
- Zeitachse: Gesprächshistorie
- Balkendiagramm: Beförderungen je Halbjahr/Jahresende

## 5. App zusammenstellen (Model-driven App Designer)

Sitemap-Bereiche:
- **Dashboard** (Startseite)
- **Team** → Team Member
- **Projekte** → Project (Assignment als Subgrid auf Project- und Team-Member-Formular)
- **Entwicklung** → Development Item
- **Feedback** → Wish, Retro Note
- **Gespräche** → Conversation

Nach dem Zusammenstellen: **Speichern & Veröffentlichen**.

## 6. Optional — Automatisierung (Phase 2)

- Power-Automate-Flow: Erinnerung (Teams/E-Mail), wenn letztes Review-Gespräch > 5 Monate zurückliegt
- Power-Automate-Flow: Erinnerung bei anstehenden Trainings-Deadlines
- Business Rule oder Flow auf Conversation: bei `Beförderungsrelevant = Ja` → `Team Member.Level/Seniorität` automatisch auf `Neues Level` setzen

## 7. Optional — ALM/Source Control (Phase 3)

```
pac auth create --environment https://make.powerapps.com/environments/e7521bca-3922-e988-b5ef-24eb94ac0b14/home
pac solution export --name TeamLeadCockpit --path ./export --managed false
pac solution unpack --zipfile ./export/TeamLeadCockpit.zip --folder ./solutions/TeamLeadCockpit --packagetype Unmanaged
```
(`pac auth create` läuft interaktiv mit deinem Microsoft-Login auf deiner eigenen Maschine, nicht in dieser Claude-Code-Session — hier gibt es keinen Zugriff auf deinen Tenant.)
Ergebnis in diesem Repo unter `solutions/TeamLeadCockpit/` versionieren.

## Verifikation (End-to-End-Test)

1. Testmitarbeiter anlegen
2. Assignment für Testmitarbeiter + Testprojekt anlegen → Auslastung erscheint im Dashboard-Chart
3. Conversation Typ "Jahresendgespräch" mit Datum vor 12 Monaten anlegen → erscheint in "Anstehende Review-Gespräche"
4. Conversation Typ "Halbjahresgespräch" mit `Beförderungsrelevant = Ja` + `Neues Level` anlegen → erscheint in "Beförderungen dieses Jahr", `Team Member.Level` entsprechend aktuell
5. Sicherheitsrolle "Team Lead" prüfen: einzige Rolle mit Zugriff auf Conversation/Wish
