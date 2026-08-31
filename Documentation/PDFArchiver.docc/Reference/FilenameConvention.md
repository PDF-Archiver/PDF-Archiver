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

Descriptions and tags are reduced to plain letters: accents are spelled out
(`ä` becomes `ae`), symbols and spaces are removed, and everything is
lowercased. This keeps names readable on any system, which matters when the same
archive is opened on a Mac, an iPhone and whatever syncs it in between.

Tags are sorted so that the same set of tags always produces the same filename,
whatever order they were typed in.

### What makes a name parseable

A document counts as filed when the name yields all three parts: a date, a
non-empty description, and at least one tag. Anything else is treated as
untagged — including a document that carries a date and description but no tags
yet.

A document that is missing one of the three is shown in the untagged list,
waiting for you to complete it.

### Year folders

Documents are grouped into a folder per year, taken from the date in the name.
The folder is a convenience for browsing outside the app; the app itself finds
documents by scanning, not by relying on the layout.
