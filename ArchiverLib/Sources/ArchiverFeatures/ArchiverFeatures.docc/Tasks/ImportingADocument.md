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

Imports are serialized in a queue, so a large scan does not compete with a drop
that arrives while it runs.

### Nothing is lost if the app stops

An incoming document is persisted in the staging folder **before** it enters the
queue and deleted only **after** the finished PDF has been written. If the app is
killed halfway, the file is still in staging and is picked up on the next launch.
The worst case is a duplicate import; the case that cannot happen is a lost
document.

Multi-page scans share a filename prefix, so an interrupted scan comes back as
one document rather than a pile of loose pages.

### PDFs are not re-encoded

A PDF that arrives as a PDF is moved, not rebuilt. Its bytes stay as they were.
Re-encoding only happens where an image has to become a PDF, or where a page
without a text layer is rendered again to carry one — see
<doc:HowADocumentMoves>.
