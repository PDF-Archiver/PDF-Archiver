# How a document moves

What happens between dropping a document in and filing it.

## Overview

A document passes through two folders. It arrives in the **untagged** one and
leaves for the **archive** when you save it with a name. Everything in between
happens on its own.

### Arriving

However a document comes in — camera, drag and drop, share sheet, or a scanner
writing straight into the folder — it ends up in the untagged folder with a
placeholder name. Images become PDFs on the way. A document that is already a
PDF is moved as it is, without being re-encoded, so nothing about it changes.

Imports happen one at a time. A long scan does not slow down a file you drop
while it runs; it just waits its turn.

### Waiting to be filed

While a document sits untagged, the app prepares it so that filing is quick:

1. **Text.** If the document has no text layer and automatic OCR is on, one is
   added — invisibly, so the document looks unchanged, but the words become
   selectable and searchable.
2. **Suggestions.** If Apple Intelligence is on, a description and tags are
   worked out ahead of time and remembered, so the form is already filled in when
   you open it.

The order matters: text first, then suggestions, because a suggestion is made
from the text.

On iPhone and iPad this also continues while the device is charging, so a batch
of scans is usually ready by the time you come back to it.

### Being filed

Opening a document shows it beside the three fields that become its name. Saving
renames it and moves it into the archive, into a folder for its year.

That is the last automatic step. From then on the document is an ordinary PDF
with a descriptive name, in a folder you can open anywhere.

### If something goes wrong

An incoming document is written to disk before anything else happens to it, and
removed only once the finished document is in the untagged folder. If the app is
interrupted — a crash, a phone call, a device running out of battery — the
document is picked up again next time. A page of a multi-page scan is never
stranded on its own.

The one thing that can happen is the same document arriving twice. Nothing is
ever lost.
