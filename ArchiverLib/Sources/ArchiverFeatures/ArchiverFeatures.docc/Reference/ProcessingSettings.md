# Processing settings

The four settings that change what happens to a document before you see it.

## Overview

| Setting | Default | Effect |
|---|---|---|
| Automatic OCR for image PDFs | off | Adds a text layer to untagged PDFs that have none |
| Apple Intelligence | off | Suggests a description and tags |
| Suggestion cache | on with Apple Intelligence | Computes suggestions ahead of time instead of on open |
| PDF quality | — | JPEG compression for scanned pages and re-rendered OCR pages |

### Automatic OCR

A PDF from a desktop scanner often has no text layer. With this on, the app runs
Vision over such documents in the untagged folder and writes an invisible text
layer into the file, in place — the filename does not change.

This is also what makes Apple Intelligence useful for scans: the suggestion is
built from the text layer, so a document without one has nothing to suggest from.

OCR is attempted once per document. The result is recorded in the PDF's `Creator`
attribute, so a document that failed is not retried on every pass. If it later
gains a text layer by other means, that wins over the marker.

### PDF quality

Applies where pages are rendered: scanned pages, and pages rewritten to carry an
OCR text layer. A PDF that arrives as a PDF and needs no text layer is moved
untouched, so this setting never degrades a document that was already fine.

### Background processing

On iOS the OCR and suggestion passes also run as a background task while the
device is on external power. OCR runs first, so suggestions are computed from
text layers that already exist.
