# 0003 — The SQLite database is a derived read model, never a second source of truth

**Status:** accepted, 2026-09-13 — replaces the in-memory `@Shared(.documents)` list.

## Context

Every screen read one in-memory array and looped over it: archive list, inbox, statistics, tag
suggestions, widget counts. Search was a substring match on the filename.

Searching *inside* the PDFs does not fit that shape: the index must survive launches, and one
keystroke has to combine tag and year filters with content hits and rank the result, which over an
array means holding every document's text in memory. The archive is also a folder of PDFs the user
edits in the Finder, on another device, from a backup, so any index over it is a copy that can be
invalidated at any moment.

## Decision

A local SQLite database ([SQLiteData](https://github.com/pointfreeco/sqlite-data)) becomes the
single read model for every screen — documents, tags, extracted text, indexer state. Full-text
search is then just one more query over it, not a subsystem of its own.

- **The file system stays the truth.** Every table can be dropped and re-derived; a partially
  applied snapshot is fine, since the next one corrects it.
- **One writer.** `ArchiveIndexer` reconciles folder snapshots; features read through `@FetchAll` /
  `@FetchOne` / `@Fetch` and never write, not even optimistically.
- **Ids come from the file system**, not an autoincrement key: `documentIdentifier` survives
  renames, moves and rebuilds, and tagging a document *renames* it.
- **Metadata is immediate, text is deferred** — background, external power only, Premium only.
- **The database is local and disposable**: Application Support, one per device, no CloudKit, not
  in the App Group. One that cannot be migrated is deleted and rebuilt.

## Consequences

- Features never write — a save or delete becomes visible only once the file-system event arrives,
  which is why `AppFeature`'s optimistic edits were removed rather than ported.
- "Rebuild search index" truncates and rescans, repairing every derived-data bug; available without
  Premium for that reason.
- `date` is stored as UTC — year buckets must come from the `year` column, never from `date`.
- The first index can take several nights on iOS, since processing tasks run only while idle and
  charging. Accepted; the search-index settings screen shows progress.

## Alternatives considered

- **A side index for search only**: still needs path/size/date bookkeeping to detect staleness —
  most of a read model — and leaves filters intersecting FTS hits in memory.
- **Core Spotlight**: system-wide by design, no app-private index, no joins, opaque ranking, no
  snippets, throttled and hard to test.
- **macOS `kMDItemTextContent` queries**: macOS-only, blind to evicted iCloud files, no snippet text
  — would leave iOS without content search.
- **Syncing text via CloudKit**: entitlement, quota and conflict handling for text FTS5 cannot sync
  anyway. Nothing in the schema prevents adding it later.
- **A `trigram` tokenizer** for German compounds: three times the index size and a three-character
  minimum. Switching later is one migration plus a rebuild.
