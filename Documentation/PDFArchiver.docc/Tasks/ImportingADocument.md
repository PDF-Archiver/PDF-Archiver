# Importing a document

Four ways in, one destination.

## Overview

Everything lands in the untagged folder, whatever route it took:

| Route | What happens |
|---|---|
| Camera scan | Pages are photographed, run through Vision OCR and written as a searchable PDF |
| Drag & drop, file importer | A PDF is validated and moved; an image is turned into a PDF first |
| Share extension | The file is written to a staging folder and picked up when the app next runs |
| Straight into the folder | A desktop scanner or Files.app writes the PDF; the folder watcher notices |

Imports happen one at a time, so a large scan does not slow down a file you drop
while it runs.

### Nothing is lost if the app stops

An incoming document is written to disk before anything else happens to it, and
removed only once the finished PDF exists. If the app is interrupted halfway, the
document is picked up again next time you open it. The worst case is the same
document arriving twice; the case that cannot happen is a lost document.

An interrupted multi-page scan comes back as one document rather than a pile of
loose pages.

### PDFs are not re-encoded

A PDF that arrives as a PDF is moved, not rebuilt. Its bytes stay as they were.
Re-encoding only happens where an image has to become a PDF, or where a page
without a text layer is rendered again to carry one — see
<doc:HowADocumentMoves>.
