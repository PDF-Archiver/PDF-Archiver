# Review-Zwischenschritt 2: ArchiverStore (Store, FolderProvider, Watcher, PathManager)

Stand: 2026-07-04 · Scope: `ArchiverLib/Sources/ArchiverStore`

## Mögliche Bugs

### B6 (mittel): Gelöschte/neu erstellte Ordner werden nicht mehr überwacht
- `DirectoryDeepWatcher.createAndAddSource()` legt pro Ordner-URL genau eine Quelle an und behält sie für immer (`sources[url] == nil`-Guard, `DirectoryDeepWatcher.swift:75`).
- Wird ein Ordner gelöscht und später mit gleichem Namen neu angelegt (z.B. Jahresordner beim Archiv-Umzug), zeigt der alte File-Deskriptor auf den gelöschten Inode; eine neue Quelle wird wegen des Guards nie erstellt → Änderungen in dem neuen Ordner lösen keine Events mehr aus.
- Außerdem wachsen `sources` und offene File-Deskriptoren monoton (nie entfernt außer bei `stop()`).

### B7 (niedrig): File-Deskriptor-Leak in `DirectoryDeepWatcher.deinit`
- `deinit` cancelt nur die Tasks (`source.1.cancel()`), nicht die `DispatchSourceWatcher` (`source.0`). Der `setCancelHandler` (der `close(descriptor)` macht) läuft dadurch nie → offene Deskriptoren bleiben zurück, wenn der Watcher ohne `stop()` freigegeben wird (`DirectoryDeepWatcher.swift:38-43` vs. `146-148`).

### B8 (niedrig): `preconditionFailure` bei unbekanntem iCloud-Downloadstatus
- `NSMetadataItem.createDetails()` crasht die App mit `preconditionFailure`, wenn Apple einen neuen Statuswert einführt (`ICloudFolderProvider.swift:247`). Besser `return nil` nach dem `criticalAndAssert`.

### B9 (niedrig): Assertion-Rauschen bei iCloud-Löschungen
- In `sendDocuments()` wird für entfernte Dateien `url.uniqueId()` aufgerufen (`ICloudFolderProvider.swift:128`). `uniqueId()` liest Resource-Values von der Platte — bei einer gerade gelöschten Datei schlägt das fehl → `assertionFailure` bei jeder Löschung in Debug-Builds. Der Fallback (Filter über URL) existiert, aber der Assert ist irreführend.

### B10 (niedrig): Doppelte, inkonsistente `getUntaggedUrl`-Implementierung
- `ArchiveStore.getUntaggedUrl()` (`ArchiveStore.swift:72-74`) baut den Pfad selbst (`appending(component: "untagged")`) und legt den Ordner **nicht** an; `PathManager.getUntaggedUrl()` (`PathManager.swift:58-62`) macht dasselbe inkl. `createFolderIfNotExists`. Zwei Quellen für dieselbe Wahrheit → Drift-Gefahr. `ArchiveStore.getUntaggedUrl()` sollte an den PathManager delegieren.

### B11 (niedrig): `archivePathType` wird auch bei fehlgeschlagenem Umzug gesetzt
- `PathManager.setArchiveUrl()` merkt sich Move-Fehler, setzt aber `archivePathType` **vor** dem `throw` (`PathManager.swift:101-105`). Schlägt der Umzug teilweise fehl, zeigt die App auf das neue Archiv, obwohl Teile noch am alten Ort liegen. Vermutlich gewollt ("weiter geht's am neuen Ort"), sollte aber zumindest dokumentiert sein.

## Vereinfachungen

### S6: Totes Flag `removeOldDocumentsInNextSync`
- Wird zweimal auf `true` gesetzt (`ArchiveStore.swift:45, 276`), aber nirgends gelesen. Entweder fehlt hier Logik (Alt-Dokumente entfernen) oder das Feld kann ersatzlos weg — `update()` baut `documentsMap` ohnehin pro Aufruf neu auf.

### S7: Singleton-Selbstaufruf
- `ArchiveStore.update(with:)` ruft `await ArchiveStore.shared.update(...)` auf, obwohl `self` bereits die Instanz ist (`ArchiveStore.swift:69`). Einfach `await update(...)`.

### S8: Duplizierte Tag-Sortierlogik
- `getTagSuggestionsSimilar(to:)` und `getTagSuggestions(for:)` enthalten identisches Sortieren+`prefix(5)`+`map(\.key)` (`ArchiveStore.swift:225-236, 249-260`). In eine Helper-Funktion ziehen.

### S9: Duplizierte `save`/`rename`-Implementierungen in den Providern
- `ICloudFolderProvider` und `LocalFolderProvider` haben (bis auf `delete`) identische `save`, `fetch`, `rename` (inkl. identischer Kommentare). Kandidat für eine Protocol-Extension von `FolderProvider`.

### S10: Auskommentierter Code
- `ICloudFolderProvider.swift:34-36` (Jahres-Prädikat), `:177-180` (Guard in `startDownload`), `ArchiveStoreDependency.swift:32-50` (Preview-Stream), stale Kommentar `ICloudFolderProvider.swift:56-60` ("We supply our own serializing queue" — es ist `.main`).

### S11: `isLoading`-Wrapper leakt Task
- `ArchiveStoreDependency.liveValue.isLoading` wickelt das `AsyncCurrentValueSubject` in `AsyncStream { Task { … } }` (`ArchiveStoreDependency.swift:81-88`) — der Task wird nie beendet, wenn der Konsument abbricht (`onTermination` fehlt). Alternativ das Subject direkt/`eraseToStream()` nutzen.

## Beobachtungen
- `ArchiveStore.documentsStream` ist ein einfacher `AsyncStream`, der über die Dependency geteilt wird — `AsyncStream` unterstützt nur **einen** Konsumenten. Aktuell abonniert nur `AppFeature`; ein zweiter Abonnent würde Werte "klauen". Fragil, aber heute kein Bug.
- `getProvider(for:)` und `isTagged(_:)` matchen per `path.contains(...)` (Substring statt Präfix). Der Kommentar erklärt das `/private`-Symlink-Problem; ein `hasSuffix`-basiertes Matching wäre präziser (z.B. matcht `/a/b` auch `/x/a/b-backup` nicht ganz korrekt).
- `LocalFolderProvider.getDownloadStatus`: Magic Number `0.123` als "lädt gerade". Funktioniert, weil UI vermutlich nur `==0`/`==1` unterscheidet, ist aber undurchsichtig.
- `Document.create()` wandelt für getaggte Dokumente `-` in Leerzeichen in der Spezifikation um (Anzeige-Transformation im Modell) — Konsistenz mit `createFilename` (das nicht slugifiziert) in Pass 3 prüfen.
