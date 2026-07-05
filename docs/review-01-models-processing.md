# Review-Zwischenschritt 1: ArchiverModels, ArchiverDocumentProcessing, Shared-Parser

Stand: 2026-07-04 · Scope: `ArchiverLib/Sources/ArchiverModels`, `ArchiverLib/Sources/ArchiverDocumentProcessing`, `ArchiverLib/Sources/Shared` (Parser/Helper)

## Mögliche Bugs

### B1 (mittel): `.jpg`-Temp-Dateien werden nach einem Abbruch nie wieder aufgeräumt/verarbeitet
- `PDFProcessingOperation.save()` schreibt Bild-Kopien als `…​.jpg` in `Constants.tempDocumentURL` (`PDFProcessing.swift:299`).
- `DocumentProcessingService.handleFolderContents()` scannt den Ordner aber nur nach Suffix `"pdf"` und `"jpeg"` (`DocumentProcessingService.swift:89-90`).
- Wird die App während der Verarbeitung beendet (Crash, Kill), bleiben die `.jpg`-Dateien für immer im Temp-Ordner liegen — sie werden weder erneut verarbeitet noch gelöscht. Gescannte Seiten können so verloren gehen; der App-Group-Container wächst.

### B2 (niedrig): `NSRange` mit `raw.count` statt `raw.utf16.count`
- `DateParser.localParse()` verwendet `NSRange(location: 0, length: raw.count)` (`DateParser.swift:54`).
- `NSDataDetector` arbeitet auf UTF-16-Einheiten. Bei Nicht-ASCII-Inhalt (Umlaute im OCR-Text, Emoji) ist `raw.count < raw.utf16.count` → der durchsuchte Bereich ist zu kurz, Daten am Textende werden übersehen.
- Fix: `NSRange(raw.startIndex..., in: raw)`.

### B3 (niedrig): Division durch 0 / `NaN`-Expansion bei leerem OCR-Text
- `NSAttributedString.createCleared()` rechnet `em = actualWidth.width / CGFloat(text.count)` (`PDFProcessing.swift:374`).
- In `createPdf()` kann `fullObservation` leer sein (Results vorhanden, aber alle Kandidaten leer → `thisObservation` leer, `joined` = `""`, Result wird trotzdem angehängt, `PDFProcessing.swift:179-189`). Dann `text.count == 0` → `NaN`-Expansion im Attribut.
- Fix: leere `fullObservation` nicht als `TextObservationResult` anhängen.

### B4 (niedrig): `fatalError` im Produktions-Codepfad
- `createPdf()`: `guard let cgImage = image.cgImage else { fatalError(...) }` (`PDFProcessing.swift:146`) und `renderPdf()` (`PDFProcessing.swift:255`).
- Ein einzelnes defektes Bild crasht die ganze App, obwohl der Rest des Codes das `errorAndAssert`-Pattern (Log + Assert im Debug, weiter im Release) benutzt. Besser: Bild überspringen + `errorAndAssert`.

### B5 (niedrig): Datei-Filter matcht zu großzügig
- `$0.lastPathComponent.lowercased().hasSuffix("pdf")` matcht auch `mypdf` oder `report.not-pdf` (`DocumentProcessingService.swift:89`). Besser: `pathExtension == "pdf"` bzw. `["jpg", "jpeg"]` (behebt zusammen mit B1 auch den jpg/jpeg-Mismatch).

## Vereinfachungen

### S1: Toter Code in `parseFilename`
- `Document+Helper.swift:49-67`: großer auskommentierter Block (+ auskommentiertes `rawDate`, Zeilen 28/31). Löschen.

### S2: Nutzlose Casts
- `Document+Helper.swift:96/98`: `filename.components(separatedBy: "--") as [String]?` — der Cast ist immer erfolgreich, `if let` ist Verkleidung. Einfach `let components = …; if components.count > 1`.
- `PDFProcessing.swift:112`: `await Document.parseFilename(…) as (…)?` — Rückgabewert ist nie optional, Cast + `let`-Bindung überflüssig.

### S3: `.lazy` ohne Wirkung
- `DateParser.swift:55-56`: `matches.lazy.compactMap { … }` mit Rückgabetyp `[ParserResult]` → Swift wählt die eager-Überladung, `.lazy` bringt nichts. Entfernen.

### S4: Tag-String-Bau
- `Document.createFilename` (`Document.swift:52-56`): Schleife + `dropLast` ersetzen durch `tags.sorted().joined(separator: "_")`.

### S5: Wegwerf-Fehlertyp
- `PDFProcessing.swift:70-74`: lokale `enum OptionalError` im Guard. Ein gemeinsamer Fehlertyp (oder `FolderProviderError`-Pendant) wäre klarer.

## Fragen / Beobachtungen (kein Handlungsbedarf ohne Rückfrage)
- `DateParser` filtert bewusst alle Daten, die "heute" sind (NSDataDetector-Workaround). Dokumente, die tatsächlich das heutige Datum tragen, werden dadurch nie erkannt — bekanntes Trade-off?
- `Document.createFilename` slugifiziert die `specification` nicht selbst; Aufrufer müssen das tun (wird in Pass 3 bei `DocumentInformationForm` geprüft).
- `parseFilename` verlangt exakt einen `--`- und einen `__`-Separator (`components.count == 2`); ein `--` in der Beschreibung lässt das Parsen der Spezifikation scheitern. Konventionstreu, aber fragil.
