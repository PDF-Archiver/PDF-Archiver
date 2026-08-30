# Filename convention

The exact shape of a filed document's name.

## Overview

```
yyyy-mm-dd--description__tag1_tag2_tag3.pdf
```

stored at `Archive/<yyyy>/`.

| Part | Rule |
|---|---|
| Date | ISO `yyyy-mm-dd` |
| Separator | `--` between date and description |
| Description | Lowercase, words joined by `-` |
| Separator | `__` between description and tags |
| Tags | Lowercase, separated by `_`, sorted alphabetically |
| Extension | `.pdf` |

Example:

```
Archive/2024/2024-03-11--stromabrechnung-eon__rechnung_strom.pdf
```

### Character handling

Descriptions and tags are slugified: diacritics are folded (`ä` becomes `ae`),
symbols and whitespace are removed, and everything is lowercased. This keeps
names portable across filesystems, which matters when the same archive is opened
on macOS, iOS and whatever syncs it in between.

Tags are sorted so that the same set of tags always produces the same filename,
whatever order they were typed in.

### What makes a name parseable

A document counts as filed when the name yields all three parts: a date, a
non-empty description, and at least one tag. Anything else is treated as
untagged — including a document that carries a date and description but no tags
yet.

This is also what makes the archive usable as ground truth: a filed name is a
decision a human made, and can be compared against
(<doc:HowSuggestionsAreMeasured>).

### Year folders

Documents are grouped into a folder per year, taken from the date in the name.
The folder is a convenience for browsing outside the app; the app itself finds
documents by scanning, not by relying on the layout.
