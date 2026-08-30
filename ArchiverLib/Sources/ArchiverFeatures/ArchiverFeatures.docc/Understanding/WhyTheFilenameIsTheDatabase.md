# Why the filename is the database

The one decision the rest of the app follows from.

## Overview

Most document managers keep a database and treat the files as payload. PDF
Archiver keeps files and treats the database as unnecessary. Date, description
and tags live in the name:

```
2024-03-11--stromabrechnung-eon__rechnung_strom.pdf
```

### What that buys

**The archive outlives the app.** A folder of named PDFs needs no reader. If this
app is gone in ten years, the archive is still an archive — in Finder, in
Spotlight, on any operating system, in any backup.

**Sync is somebody else's problem, solved.** Two devices agree because iCloud
Drive already makes them agree about files. There is no merge logic, no
conflicting index, no repair tool, because there is no second copy of the truth.

**Every tool already works.** Search, backup, versioning, scripts. A `find` over
the archive is a query. `mv` is an edit.

**Nothing can drift out of sync.** A database can disagree with the files it
describes; a filename cannot disagree with itself.

### What it costs

**The name is a schema, and schemas constrain.** Descriptions have to be
slugified; tags have to be single lowercase words. Filesystem limits are real
limits.

**Renaming is editing.** Changing a tag means renaming the file. That is cheap,
but it does mean the archive's history is the filesystem's history, not the
app's.

**Search is filename search.** Not full text — see <doc:SearchingTheArchive> for
what that does and does not reach.

**Filing takes a decision.** Something has to choose the words. That is the job
the suggestions exist to make lighter, which is why they are built from the
archive's own vocabulary rather than a general one
(<doc:HowSuggestionsAreMade>).
