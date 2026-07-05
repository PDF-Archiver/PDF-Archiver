# Review-Zwischenschritt 3: ArchiverFeatures (TCA-Reducer + Views)

Stand: 2026-07-04 · Scope: `AppFeature`, `ArchiveList`, `UntaggedDocumentList`, `DocumentDetails`, `DocumentInformationForm`, `Statistics`, `Settings`

## Mögliche Bugs

### B12 (niedrig): Leerer Such-Token filtert alles weg
- `ArchiveList`-Reducer, `binding(\.searchText)` (`ArchiveList.swift:110-117`): Endet die Eingabe mit einem Leerzeichen, wird der Rest slugifiziert und als `.text`-Token angehängt — **ohne Leer-Check**. Tippt man nur ein Leerzeichen (oder z.B. `"! "`), entsteht `.text("")`; `localizedCaseInsensitiveContains("")` ist `false` → die Liste ist plötzlich leer und der unsichtbare Token muss manuell entfernt werden.

### B13 (niedrig): Hartkodierte Jahres-Vorschläge `2025/2024`
- `ArchiveList.State.searchSuggestedTokens = [.year(2025), .year(2024)]` (`ArchiveList.swift:53`). Wird zwar von `AppFeature.documentsChanged` überschrieben, ist aber bis dahin sichtbar und veraltet jedes Jahr. Besser aus `Date()` ableiten oder leer starten.

### B14 (niedrig): AI-Ergebnis überschreibt Nutzereingaben
- `DocumentInformationForm.updateDocumentData` überschreibt `document.date/specification/tags` bedingungslos (`DocumentInformationForm.swift:239-247`), und `startUpdatingAllSuggestionsWithAI` liefert `date`/`specification`/`tags` **nie** als `nil` (`:337-341`, `?? Date()`, `?? ""`). Tippt der Nutzer während des (bis zu mehrere Sekunden laufenden) AI-Laufs bereits Spezifikation/Tags, werden diese beim Eintreffen des Ergebnisses überschrieben — ggf. sogar mit `""`.

### B15 (niedrig): `assertionFailure` bei "Contact & Help" auf macOS im Debug-Build
- `Settings.onContactSupportTapped` (`Settings.swift:166-170`): Im DEBUG-Zweig feuert bei jedem Tap `assertionFailure("TODO: …")`. Außerdem ist die Mailto-URL nicht encodiert (`subject=PDF Archiver: Support` enthält Leerzeichen/Doppelpunkt) und wird force-unwrapped — auf älteren Foundation-Parsern ein Crash-Kandidat. `URLComponents` benutzen.

### B16 (Beobachtung): `XCTFail` im Produktions-Reducer
- `AppFeature.swift:122`: `XCTFail("Document that was saved not found …")` im Save-Pfad. Außerhalb von Tests ein No-Op, aber `reportIssue` (IssueReporting) ist das dafür gedachte, modernere API. Außerdem wird die Liste nur in diesem Fehlerzweig neu sortiert — ändert der Nutzer das Datum eines Dokuments, bleibt die Sortierung bis zum nächsten Datei-Sync veraltet.

## Vereinfachungen

### S12: Vierfach dupliziertes "Top-Tags zählen und sortieren"
Identischer Code (Count-Map bauen → nach Häufigkeit, dann alphabetisch sortieren → `prefix(n)`):
1. `ArchiveStore.getTagSuggestionsSimilar(to:)` (`ArchiveStore.swift:219-234`)
2. `ArchiveStore.getTagSuggestions(for:)` (`ArchiveStore.swift:245-259`)
3. `AppFeature.documentsChanged` (`AppFeature.swift:185-198`)
4. `Statistics.documentsUpdated` (`Statistics.swift:58-72`)
→ Ein Helper à la `Sequence<String>.topByCount(_ n: Int)` in `Shared` würde ~40 Zeilen sparen und die Tie-Break-Regel an einer Stelle festlegen.

### S13: Redundanter Filter
- `AppFeature.swift:212`: `untaggedDocuments.filter { !$0.isTagged && … }` — `untaggedDocuments` enthält bereits nur ungetaggte Dokumente; `!$0.isTagged` ist immer `true`.

### S14: Effekt ohne Mehrwert
- `AppFeature.documentsChanged` gibt `.run { send in await send(.prefetchDocuments(…)); await send(.updateWidget(…)) }` zurück (`AppFeature.swift:214-217`). `.merge(.send(…), .send(…))` oder direkt die Arbeit in einem Effekt ausführen wäre klarer; die Zwischen-Actions `prefetchDocuments`/`updateWidget` haben keine weitere Logik.
- Gleiches Muster in `DocumentInformationForm.onTask` (`:201-207`): der `.run`-Effekt sendet nur eine weitere Action.

### S15: Doppelte Destination-Switches in Settings
- `SettingsView.navigationDestination` (`Settings.swift:273-318`) und `SettingsMacView.sheet` (`:425-458`) enthalten fast identische 8-Fälle-Switches. Ein gemeinsamer `destinationView(for:)`-Builder halbiert das.
- Dazu: `preconditionFailure("Failed to load export nothing found")` (`:287, :294`) — Copy-Paste-Fehlermeldungen; im View-Code wäre ein leerer Fallback robuster als ein Crash.

### S16: Kleinkram
- `Settings`/`SettingsMac`: `private static let appId = 1433801905` ist in beiden Views ungenutzt (URL ist separat hartkodiert).
- `AppFeature.documentsChanged`: `.sorted { $0.date < $1.date }.reversed()` → `.sorted { $0.date > $1.date }`.
- `DocumentInformationForm.startUpdatingAllSuggestionsWithAI`: nutzt gemischt `Calendar.current` (`:298`) und die `@Dependency(\.calendar)` (`:304`) — für Tests sollte durchgängig die Dependency verwendet werden. Auskommentierte Zeilen `:305-306` löschen.
- `DocumentDetails.swift:231`: Kommentar "iOS Bug …" steht im `#else`(=macOS)-Zweig; die Plattform-Kommentare bei Share sind vertauscht/verwirrend.

## Positives
- Konsequentes Delegate-Pattern zwischen Kind- und Eltern-Reducern; `@Shared(.documents)` als Single Source of Truth funktioniert sauber.
- `ArchiveListView` cached `store.filteredDocuments` bewusst einmal pro Render-Zyklus.
- Gute Verwendung von `cancellable(id:cancelInFlight:)` für Suggestion-Fetches und den Tag-Delay-Timer.
