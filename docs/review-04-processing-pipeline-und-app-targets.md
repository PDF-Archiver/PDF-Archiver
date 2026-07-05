# Review-Zwischenschritt 4: Import-Pipeline, ShareExtension, ContentExtractor, Hintergrund-Tasks

Stand: 2026-07-04 · Scope: `PDFDropHandler`, `ShareExtension`, `ContentExtractorStore`, `BackgroundTaskManager`, `SharedKeys`, Dependencies

## Mögliche Bugs

### B17 (mittel, zu verifizieren): Doppel-Import-Race beim PDF-Drop/-Import
Mechanik:
1. Drop eines PDFs → `PDFDropHandler.handle(pdf:)` → `DocumentProcessingService.handle(pdfData:url:)` → `PDFProcessingOperation` wird erzeugt; deren `save()` schreibt sofort eine Temp-Kopie `TempDocuments/<originalname>.pdf` (`PDFProcessing.swift:288-292`).
2. Direkt danach ruft `finishDropHandling()` `triggerFolderObservation()` auf (`PDFDropHandler.swift:101`).
3. Der Scan (`handleFolderContents`) findet die noch nicht gelöschte Temp-Kopie und erzeugt eine **zweite** Operation für dieselbe Datei (`DocumentProcessingService.swift:93-106`).
4. Ist der Original-Dateiname nicht im Archiv-Schema parsebar, erzeugen beide Operationen unterschiedliche Platzhalter-Namen (`…TEMP-DESCRIPTION-<timestamp>…`) → das Dokument landet **zweimal** im Eingang. Bei parsebarem Namen schlägt die zweite Operation mit `renameFailedFileAlreadyExists` fehl → Fehler-Assert/Alert.

Der `isObserving`-Guard schützt nur vor parallelen Scans, nicht vor diesem Rennen. Bei Bildern passiert das nicht — vermutlich genau deshalb ist der Scan-Filter `"jpeg"`, während `save()` `.jpg` schreibt (siehe B1). Fix-Idee: `save()`-Temp-Kopien in einen Unterordner (z.B. `TempDocuments/processing/`) legen, den der Scan überspringt — löst B1 und B17 zusammen sauber.

### B18 (mittel, zu verifizieren): `BGTaskScheduler.register` wird zu spät aufgerufen
- `BackgroundTaskManager.registerTaskHandlers()` läuft in `AppFeature.onLongBackgroundTask` (`AppFeature.swift:233`), also aus dem `.task`-Modifier der Root-View — **nach** Abschluss des App-Launches.
- Apple verlangt, dass alle Launch-Handler "before the end of the app launch sequence" registriert werden; verspätete Registrierung wirft klassisch eine `NSInternalInconsistencyException`. Wenn das auf iOS 26 bisher gut ging, ist es Glück/undokumentiert. Registrierung gehört in den App-/Scene-Init.

### B19 (niedrig): Tag-Statistik für den AI-Prompt ist unsortiert
- `ContentExtractorStore.getDocumentStats()`: `Dictionary(grouping:)` → `map` → `filter` → `prefix(30)` (`ContentExtractorStore.swift:210-218`). Ohne Sortierung liefert `prefix(30)` **zufällige** 30 Tags, obwohl die Instruktion verspricht "Prefer frequently used tags". Vor `prefix` nach `count` absteigend sortieren.

### B20 (niedrig): `print(docStats)` im Produktionscode
- `ContentExtractorStore.createSession` (`ContentExtractorStore.swift:174`): Debug-`print` gibt Dokument-Titel/Tags (private Daten) auf stdout aus. Entfernen oder durch `Logger.debug` ersetzen.

### B21 (niedrig): Settings-Label behauptet falschen Default für PDF-Qualität
- Default ist `.lossless` (`SharedKeys.swift:61`), aber das Picker-Label sagt "75% - Good (Default)" (`Settings.swift:26`). Eines von beiden anpassen.

### B22 (niedrig): Falscher `Task.isCancelled`-Check
- `BackgroundTaskManager.handleCacheProcessing` (`BackgroundTaskManager.swift:108`): `!Task.isCancelled` prüft den umgebenden Task, nicht den abgebrochenen `processingTask`. Gemeint ist `!processingTask.isCancelled`.
- Außerdem: Die Notification-Texte ("Processing Completed", …) sind als einzige UI-Strings nicht lokalisiert.

## Vereinfachungen

### S17: Komplett auskommentierte Datei
- `Shared/Other/OpenDocumentIntent.swift`: 194 Zeilen, 100 % auskommentiert (`// TODO: add this again`). Löschen — Git hat die Historie; alternativ in einen Branch/Issue verschieben.

### S18: SharedKeys-Boilerplate
- `SharedKeys.swift`: 12 nahezu identische `SharedKey`-Paare. Auffällig dabei:
  - `AppStorageKey<Float>.pdfQuality` (`:46-50`) ist vermutlich tot — überall wird die `PDFQuality`-Variante benutzt.
  - `.ocrEnabled`-Default steckt in der `multiTagSelectionDelayEnabled`-Extension (`:161-163`) statt in einer eigenen — Struktur-Inkonsistenz.

### S19: `StorageType.title/descriptionView` doppelt
- `Settings.swift:35-70` und `StorageSelectionType` (`StorageSelection.swift:195-244`) enthalten dieselben Titel/Beschreibungstexte zweimal (inkl. desselben Apple-Support-Links, einmal davon force-unwrapped aus einem *lokalisierten* String — `Settings.swift:63`, weiterer Crash-Kandidat, falls eine Übersetzung den String verändert).

### S20: Ungenutzte Dependency
- `ContentExtractorStoreDependency` hält `@Dependency(\.archiveStore)` (`ContentExtractorStoreDependency.swift:18`), nutzt es aber nirgends.

### S21: `ContentExtractorCache.getDocumentId`
- `filename.split(separator: ".json")` (`ContentExtractorCache.swift:168`) funktioniert, ist aber ein krummer Weg; `url.deletingPathExtension().lastPathComponent` + `Int(...)` ist idiomatisch. `getCachedDocumentIds()` wird zudem nirgends aufgerufen (toter Code).

## Positives
- `ShareViewController.migrateLegacyDocuments` ist sauber dokumentiert inkl. Version und Ablaufplan ("can be removed after some time" — Version 4.3.0-Bug; kann bald wirklich raus).
- `ContentExtractorStoreDependency.getDocumentInformation` behandelt alle `GenerationError`-Fälle explizit inkl. `@unknown default`.
- `BackgroundTaskManager` nutzt Expiration-Handler korrekt zum Abbrechen statt sofortigem Complete.
