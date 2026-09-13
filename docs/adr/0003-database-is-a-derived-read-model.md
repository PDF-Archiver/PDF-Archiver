# 0003 — The SQLite database is a derived read model, never a second source of truth

**Status:** accepted, 2026-09-13 — replaces the in-memory `@Shared(.documents)` list.

## Context

Every screen used to read one in-memory array and loop over it for what it needed: archive list,
inbox, statistics, tag suggestions, widget counts. Search was a substring match on the filename.

Searching *inside* the PDFs does not fit that shape. The index has to survive launches, and one
keystroke has to combine tag and year filters with content hits and rank the result — over an array
that means holding every document's text in memory and intersecting two result sets by hand. But the
archive is a folder of PDFs the user owns and edits in the Finder, on another device, from a backup,
so any index over it is a copy that can be invalidated at any moment.

## Decision

A local SQLite database ([SQLiteData](https://github.com/pointfreeco/sqlite-data)) becomes the single
read model for every screen — documents, tags, extracted text, indexer state. Full-text search is
then not a subsystem of its own, just one more query over it.

- **The file system stays the truth.** Nothing the user decides is stored only in the database, and
  every table can be dropped and re-derived. A partially applied snapshot is acceptable for the same
  reason: the next one corrects it.
- **One writer.** `ArchiveIndexer` reconciles folder snapshots; features read through `@FetchAll` /
  `@FetchOne` / `@Fetch` and never write, not even optimistically.
- **Ids come from the file system**, not from the database: `documentIdentifier` survives renames,
  moves and rebuilds, and tagging a document *renames* it. An autoincrement key would change every
  id whenever the index is rebuilt.
- **Metadata is immediate, text is deferred.** Extraction runs only in the background on external
  power, and only with Premium; the list is what the user waits on.
- **The database is local and disposable.** Application Support, one per device, no CloudKit, not in
  the App Group (the Widget keeps its `SharedDefaults` counts). One that cannot be migrated is
  deleted and rebuilt.

## Consequences

- Features never write — a save or delete becomes visible when the file-system event arrives, which
  is why the optimistic edits in `AppFeature` were removed rather than ported.
- "Rebuild search index" truncates the whole read model and rescans. It repairs every derived-data
  bug, including a reconciler one, so it is available without Premium.
- `date` is stored as UTC, so year buckets must come from the `year` column, never from `date`.
- The first index can take several nights on iOS, because processing tasks run only while the device
  is idle and charging. Accepted; the search-index settings screen shows the progress.

## Alternatives considered

- **A side index for search only**, keeping the array: still needs path, size and date bookkeeping to
  detect staleness — most of a read model — and leaves filters intersecting FTS hits in memory.
- **Core Spotlight**: indexed items are by design discoverable system-wide, with no app-private
  index, no relational joins, opaque ranking, no snippets, and indexing that is throttled and hard
  to test.
- **macOS `kMDItemTextContent` queries**: macOS-only, blind to evicted iCloud files, no text back for
  snippets — it would leave iOS without content search.
- **Syncing the text via CloudKit**: entitlement, quota and conflict handling for text that FTS5
  cannot sync anyway. Nothing in the schema prevents adding it later.
- **A `trigram` tokenizer** for substring matches on German compounds: three times the index size and
  a three-character minimum. Switching is one migration plus a rebuild.
