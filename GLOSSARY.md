# PDF Archiver

PDF Archiver keeps an archive folder of PDF documents, named by date, description and tags, and lets the user find, tag and read them on iOS and macOS.

## Language

### Folders

**Folder Snapshot**:
The complete set of documents found in one archive folder at one moment.
_Avoid_: document list, folder state, file listing

**Initial Snapshot**:
The first Folder Snapshot of an archive folder after the app starts watching it; no change to that folder counts before it.
_Avoid_: first fetch, initial load, gathering result
