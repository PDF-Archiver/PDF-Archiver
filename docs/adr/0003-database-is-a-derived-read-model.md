# The SQLite database is a derived read model, never a second source of truth

Document state lives in the file system: filenames carry date, description and tags, folder
membership plus the filename pattern decide tagged vs. untagged. The database mirrors that into
queryable tables so lists, statistics, tag suggestions and full-text search share one read path, but
nothing the user decides is stored only there. Exactly one component writes to it — the
`ArchiveIndexer` actor, fed by the folder providers — and every table can be dropped and rebuilt
from the files. The one write that does not come from the indexer is the `#if DEBUG` screenshot
fixture seed, which replaces the archive rather than reflecting one.

**Considered:** keeping `@Shared(.documents)` and adding a database that holds only extracted text.
Rejected: it still needs path, size and modification-date bookkeeping to detect staleness, which is
most of a read model anyway, and it forces every tag/year filter to be intersected with FTS hits in
memory, with no sane way to rank across the two sources.

**Consequences:** features never write to the database, not even optimistically — a save or delete
becomes visible when the file-system event arrives, which is why the optimistic in-memory edits in
`AppFeature` are removed rather than ported. Any future feature that needs document state reads it
through a query; any feature that needs to *change* it changes a file through `ArchiveStore`. A user
never has to trust the index: "Rebuild search index" truncates and re-derives everything.
