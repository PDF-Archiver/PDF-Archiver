# Searching the archive

Searching filenames, not file contents.

## Overview

Search matches the parts of the filename: the description and the tags. Typing
`eon` finds `2024-03-11--stromabrechnung-eon__rechnung_strom.pdf`; so does
`strom`, because it is a tag.

This is narrower than a full-text search and deliberately so. A full-text index
would have to be built, kept up to date, and rebuilt whenever the archive is
opened somewhere new. Filenames need none of that, and they are the part you
chose on purpose — the words you decided this document should be found by.

### Why tags carry the weight

A description names one document. A tag names a group. Searching `versicherung`
should return the whole insurance shelf, which only works if the same word was
used every time — hence the app suggesting from your existing vocabulary rather
than inventing synonyms.

### Outside the app

Because the archive is a folder of ordinary files, Spotlight and Finder search
work on it too, as does `find` in a terminal. Nothing about search depends on the
app being installed.
