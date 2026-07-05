# Code-Review PDF Archiver — Gesamtbericht

Datum: 2026-07-04 · Branch: `develop` (571dc469) · Reviewer: Claude Code

> **Update 2026-07-05:** B1, B5, B6, B7, B17 sowie S1, S6, S7, S10 (teilw.), S11, S13, S17 und der Kleinkram wurden in PR #294 behoben. Datei-/Zeilenangaben in diesem Bericht beziehen sich auf den Review-Stand (571dc469).

Zwischenschritte (Details und Begründungen je Bereich):
- [Zwischenschritt 1: Modelle, Dokumentverarbeitung, Parser](review-01-models-processing.md)
- [Zwischenschritt 2: ArchiverStore-Layer](review-02-store-layer.md)
- [Zwischenschritt 3: TCA-Features](review-03-features.md)
- [Zwischenschritt 4: Import-Pipeline, ContentExtractor, Background-Tasks](review-04-processing-pipeline-und-app-targets.md)

## Zusammenfassung

Die Codebasis ist insgesamt in gutem Zustand: saubere TCA-Architektur mit Delegate-Pattern, konsequente Dependency-Injection, ein durchdachter actor-basierter Store-Layer und gute Testabdeckung der Features. Gefunden wurden **keine kritischen Fehler**, aber vier Befunde mittlerer Schwere (Datenverlust-/Duplikat-Potenzial in der Import-Pipeline, tote Ordner-Überwachung) sowie eine Reihe kleinerer Bugs und lohnender Vereinfachungen.

## Bugs nach Priorität

### Mittel

| # | Befund | Ort |
|---|--------|-----|
| B17 | **Doppel-Import-Race bei PDF-Drop**: `finishDropHandling()` triggert den Temp-Ordner-Scan, während die Temp-Kopie der gerade laufenden Operation noch existiert → dieselbe Datei wird ein zweites Mal verarbeitet (Duplikat im Eingang bzw. `renameFailedFileAlreadyExists`). | `PDFDropHandler.swift:101`, `DocumentProcessingService.swift:93`, `PDFProcessing.swift:288` |
| B1 | **Verwaiste `.jpg`-Scans gehen verloren**: Die Verarbeitung schreibt Temp-Kopien als `.jpg`, der Recovery-Scan sucht aber nur `pdf`/`jpeg`. Nach einem Crash mitten in der Verarbeitung bleiben gescannte Seiten für immer unverarbeitet im App-Group-Container liegen. Fix-Idee für B17+B1 gemeinsam: Temp-Kopien in einen vom Scan ausgenommenen Unterordner (z.B. `TempDocuments/processing/`) legen und beim App-Start dort liegengebliebene Dateien zurückholen. | `PDFProcessing.swift:299`, `DocumentProcessingService.swift:89-90` |
| B6 | **Gelöschte + neu erstellte Ordner werden nicht mehr überwacht**: `DirectoryDeepWatcher` behält pro URL für immer den alten File-Deskriptor (zeigt nach Löschung auf den toten Inode) und legt wegen des `sources[url] == nil`-Guards nie eine neue Quelle an; `sources`/Deskriptoren wachsen zudem monoton. | `DirectoryDeepWatcher.swift:75` |
| B18 | **`BGTaskScheduler.register` erst nach App-Launch**: Registrierung aus dem `.task` der Root-View widerspricht Apples Anforderung ("before the end of the app launch sequence") — klassischer `NSInternalInconsistencyException`-Kandidat. In den App-Init verschieben. | `AppFeature.swift:233`, `BackgroundTaskManager.swift:37` |

### Niedrig

| # | Befund | Ort |
|---|--------|-----|
| B4 | `fatalError` im OCR-Pfad: ein defektes Bild crasht die App (statt `errorAndAssert` + überspringen) | `PDFProcessing.swift:146, 255` |
| B8 | `preconditionFailure` bei unbekanntem iCloud-Downloadstatus — Crash, wenn Apple einen Statuswert ergänzt | `ICloudFolderProvider.swift:247` |
| B2 | `NSRange(location: 0, length: raw.count)` statt `utf16.count` — Datumserkennung übersieht bei Nicht-ASCII-Text Treffer am Ende | `DateParser.swift:54` |
| B3 | Division durch 0 → `NaN`-Expansion, wenn ein OCR-Ergebnis leeren Text liefert | `PDFProcessing.swift:374` (i.V.m. `:189`) |
| B12 | Leerer Such-Token (`.text("")`) bei Eingabe nur eines Leerzeichens filtert die komplette Liste weg | `ArchiveList.swift:110-117` |
| B13 | Hartkodierte Jahres-Suchvorschläge `2025/2024` | `ArchiveList.swift:53` |
| B14 | AI-Ergebnis überschreibt zwischenzeitliche Nutzereingaben (Datum/Spezifikation/Tags werden nie als `nil` geliefert) | `DocumentInformationForm.swift:239-247, 337-341` |
| B15 | "Contact & Help" (macOS): `assertionFailure` bei jedem Tap im Debug-Build; mailto-URL nicht encodiert + force-unwrap | `Settings.swift:163-170` |
| B19 | Tag-Statistik für den AI-Prompt unsortiert → `prefix(30)` liefert zufällige statt häufige Tags | `ContentExtractorStore.swift:210-218` |
| B20 | `print(docStats)` gibt private Dokumentdaten auf stdout aus | `ContentExtractorStore.swift:174` |
| B21 | Picker-Label "75% - Good (Default)" widerspricht echtem Default `.lossless` | `Settings.swift:26` vs. `SharedKeys.swift:61` |
| B5 | Datei-Filter per `hasSuffix("pdf")` matcht auch Nicht-PDFs (`pathExtension` nutzen) | `DocumentProcessingService.swift:89-90` |
| B7 | `DirectoryDeepWatcher.deinit` cancelt die Dispatch-Sources nicht → File-Deskriptor-Leak ohne `stop()` | `DirectoryDeepWatcher.swift:38-43` |
| B9 | `assertionFailure`-Rauschen bei jeder iCloud-Löschung (Resource-Values gelöschter Dateien nicht lesbar) | `ICloudFolderProvider.swift:128` |
| B10 | Zwei inkonsistente `getUntaggedUrl()`-Implementierungen (mit/ohne Ordner-Anlage) | `ArchiveStore.swift:72` vs. `PathManager.swift:58` |
| B11 | `archivePathType` wird auch bei teilweise fehlgeschlagenem Archiv-Umzug gesetzt (mind. dokumentieren) | `PathManager.swift:101-105` |
| B22 | `Task.isCancelled` prüft den falschen Task; Notification-Texte nicht lokalisiert | `BackgroundTaskManager.swift:108` |

## Vereinfachungen (lohnendste zuerst)

1. **S12 — Vierfach dupliziertes "Top-N-Tags zählen/sortieren"** (`ArchiveStore` ×2, `AppFeature`, `Statistics`): ein Helper in `Shared` spart ~40 Zeilen und fixiert die Tie-Break-Regel an einer Stelle.
2. **S17 — `OpenDocumentIntent.swift` löschen**: 194 Zeilen komplett auskommentierter Code.
3. **S9 — `save`/`fetch`/`rename` der FolderProvider** in eine Protocol-Extension ziehen (identisch in `ICloudFolderProvider` und `LocalFolderProvider`).
4. **S15/S19 — Settings entdoppeln**: identische Destination-Switches in `SettingsView`/`SettingsMacView`; `StorageType.title/descriptionView` doppelt zu `StorageSelectionType` (inkl. force-unwrap eines lokalisierten URL-Strings, `Settings.swift:63`).
5. **S1/S10 — Toter/auskommentierter Code**: `Document+Helper.swift:49-67`, `ICloudFolderProvider.swift:34-36, 177-180`, `ArchiveStoreDependency.swift:32-50`, `DocumentInformationForm.swift:305-306`.
6. **S6 — `removeOldDocumentsInNextSync`**: wird gesetzt, nie gelesen — entfernen (oder fehlende Logik nachziehen).
7. **Kleinkram**: nutzlose Casts (`Document+Helper.swift:96/98`, `PDFProcessing.swift:112`), wirkungsloses `.lazy` (`DateParser.swift:55`), Tag-Join per Schleife statt `joined` (`Document.swift:52-56`), Singleton-Selbstaufruf (`ArchiveStore.swift:69`), redundanter `!$0.isTagged`-Filter (`AppFeature.swift:212`), `sorted{<}.reversed()` → `sorted{>}`, ungenutzte `appId`-Konstanten (`Settings.swift`), ungenutztes `@Dependency(\.archiveStore)` (`ContentExtractorStoreDependency.swift:18`), `XCTFail` → `reportIssue` (`AppFeature.swift:122`), Task-Leak im `isLoading`-Wrapper (`ArchiveStoreDependency.swift:81-88`).

## Beobachtungen / Fragen (keine Änderung ohne Rückfrage)

- `ArchiveStore.documentsStream` ist ein Single-Consumer-`AsyncStream`, der über die Dependency geteilt wird — heute nur ein Abonnent (`AppFeature`), ein zweiter würde Werte "klauen".
- `DateParser` verwirft bewusst alle "heute"-Daten (NSDataDetector-Workaround) — Dokumente mit echtem heutigen Datum werden nie erkannt.
- Provider-Zuordnung per `path.contains(...)` (Substring) statt Präfix-Vergleich — funktioniert wegen des `/private`-Symlink-Problems, ist aber unscharf.
- `LocalFolderProvider`: Magic Number `0.123` als Download-Status "lädt gerade".
- `@Shared(.documents)` wird in `temporaryDirectory/documents.json` persistiert — bewusst als Wegwerf-Cache?

## Testlauf

`swift test` (ArchiverLib): **alle 167 Tests in 16 Suites bestanden** (Stand dieses Reviews, exit code 0). Keiner der oben genannten Befunde wird von der bestehenden Test-Suite abgedeckt — insbesondere die Import-Pipeline-Races (B1/B17) und der `DirectoryDeepWatcher` (B6/B7) wären gute Kandidaten für neue Tests.

## Methodik

Vollständig gelesen: `ArchiverModels`, `ArchiverDocumentProcessing`, `ArchiverStore`, `ContentExtractorStore`, die Kern-Features (`AppFeature`, `ArchiveList`, `UntaggedDocumentList`, `DocumentDetails`, `DocumentInformationForm`, `Statistics`, `Settings`, `ExpertSettings`, `StorageSelection`), `SharedKeys`, `ShareExtension`, `PDFDropHandler`, `BackgroundTaskManager` sowie die Shared-Parser/-Extensions. Nur überflogen bzw. nicht im Detail geprüft: Widget-Target, `ArchiverIntents`-Views, `MarkdownView`/`WrappingHStack`/`PDFCustomView`, IAP-Code, UI-Tests.
