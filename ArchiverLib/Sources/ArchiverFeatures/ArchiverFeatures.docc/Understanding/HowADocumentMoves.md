# How a document moves

From arrival to filed, and what runs in between.

## Overview

```
scan / drop / share / dropped-in-folder
                 │
                 ▼
        staging (crash-safe)
                 │
                 ▼
        processing queue  ──►  image → searchable PDF
                 │             PDF → validated, moved unchanged
                 ▼
         untagged folder
                 │
      ┌──────────┴───────────┐
      ▼                      ▼
  OCR text layer      suggestion cache
  (if enabled)        (Apple Intelligence)
                 │
                 ▼
          tagging form
                 │
                 ▼
   Archive/<year>/<name>.pdf
```

### The queue

Imports run one at a time through an actor. A scan that takes seconds does not
race a drop that arrives while it runs, and progress can be reported for the one
in flight.

### The sweep over untagged documents

Whenever the untagged folder changes, the app walks it and does two things:
adds a text layer to documents that lack one, then computes suggestions for
documents that have one. The order matters — a suggestion computed before OCR
would have nothing to read.

Both passes are designed to be repeatable. A document that already has a text
layer is skipped; one whose OCR already failed is skipped via its `Creator`
marker rather than retried forever.

### Where the boundaries are

The processing pipeline knows nothing about settings or the UI. It is handed a
configuration — destination folder, PDF quality, processed marker — and returns
documents. The settings are resolved one layer up, in the feature layer, which is
what keeps the pipeline reusable outside the app.

Likewise the content extractor knows nothing about folders. It takes document
text and existing documents, and returns a description and tags.
