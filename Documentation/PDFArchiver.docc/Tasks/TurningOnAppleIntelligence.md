# Turning on Apple Intelligence suggestions

Letting the device propose a description and tags.

## Overview

With Apple Intelligence enabled, opening an untagged document shows a filled-in
form instead of an empty one. The model runs **on the device**; the document text
does not leave it.

### What it needs

- A device and OS with Apple Intelligence available.
- A document with a readable text layer. A scan without one has nothing to read —
  turn on automatic OCR so those documents get a text layer first
  (<doc:ProcessingSettings>).

### Where the suggestions come from

Not from a general idea of what documents look like, but from your archive. Each
time the model is asked, it is shown:

- the tags you use most, so suggestions stay in your vocabulary
- example descriptions from your recent filings, so new ones read like them
- the description length your archive actually uses, measured rather than assumed
- which tags habitually appear together, so a `hornbach` receipt also gets
  `baumarkt`

<doc:HowSuggestionsAreMade> describes each of these and why it is there.

### Suggestions are computed ahead of time

Rather than making you wait when you open a document, the app works through the
untagged folder in the background and caches what it finds. On iOS this also runs
as a background task while the device is charging.

If the cache is disabled the suggestion is computed when you open the document,
which simply takes a moment longer.

### When nothing is suggested

Some documents get no suggestion, on purpose:

- The text layer is missing or unreadable — mojibake in, nonsense out, so the app
  declines rather than inventing something.
- The model's safety guardrails refuse the document.
- Every tag it proposed was outside your archive's vocabulary and was dropped.

An empty form is the honest answer in those cases. A wrong description is worse
than none, because it gets filed.
