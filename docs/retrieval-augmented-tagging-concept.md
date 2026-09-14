# Retrieval-augmented tag and description suggestions

How the content-extraction prompt gets its archive context, and why it now retrieves that context
per document instead of aggregating it once per archive. Companion to
`docs/adr/0004-visual-retrieval-is-a-fallback-channel.md` (stage 3's visual fallback).

## Design

Before this change, every extraction prompt carried the same global block:
`ContentExtractionPromptFactory.documentStats(from:)` reduces the whole tagged archive to the 30
most frequent tags and 40 recent descriptions (`minTagCount`, `maxTags`, `maxSpecifications`). That
block is a good *prior* — it teaches the model the archive's vocabulary and description style — but
it cannot teach the model anything about the specific document in front of it: a tag used five times
in the archive sits well below the frequency cutoff and can never be offered, however clearly the
current document calls for it.

Retrieval inverts the selection criterion from *frequency* to *relevance*. The `documentTexts` FTS5
table (added by #329, `ArchiverLib/Sources/ArchiverDatabase/Schema.swift`) already indexes every
tagged document's extracted text with `bm25()` ranking — the same mechanism the archive search field
uses (`Document.rankedSearch`, `ArchiverLib/Sources/ArchiverDatabase/Queries.swift`). This feature
adds one more query beside it, `Document.neighbours(matchingFTSQuery:excluding:limit:)`: given the
document being tagged, find the *k* already-tagged documents whose text best matches it, and render
them as filenames (`Document.createFilename`) in a new prompt segment
(`ContentExtractionPromptFactory.neighbourSegment`). No second index, no hand-rolled ranking — the
whole point of reusing `bm25()` is that this codebase does not maintain a ranking function of its
own.

The query differs from the search field's in one way: `DocumentText.orQuery(from:)` joins the
document's words with `OR`, not the implicit `AND` a short typed search phrase uses
(`ArchiveSearchQuery.ftsQuery`). A whole document's text should surface anything sharing *some* of
its vocabulary; requiring every one of a document's hundreds of words to appear in a candidate would
match almost nothing.

Neighbours augment the global block, they never replace it: when nothing survives the relevance
floor, the prompt is unchanged from today (`ContentExtractionPromptFactory.survivingNeighbours`,
tested in `ContentExtractorStoreUnitTests`).

### Architecture

- `ArchiverDatabase`: `Document.neighbours` (the query), `DocumentText.orQuery(from:)` (the `OR`
  match expression).
- `ContentExtractorStore` (pure, no `ArchiverDatabase` dependency): `NeighbourFinder` — a seam
  struct of closures, the same shape as `SuggestionCache` — carries the retrieved rows across the
  module boundary. `ContentExtractionPromptFactory` renders and filters them; `ContentExtractorStore`
  calls the seam and applies the floor before building the prompt.
- `ArchiverFeatures`: `NeighbourFinder.documentTexts` wires the seam to the real database query,
  the only place both `ArchiverDatabase` and `ContentExtractorStore` are available together.

## Provisional tunables — where to change them

Every constant below lives in
`ArchiverLib/Sources/ContentExtractorStore/ContentExtractionPromptFactory.swift`, with a doc comment
pointing back here, so re-tuning never means hunting through the call sites. `neighbourCount` and
`neighbourRelevanceFloor` are new with this feature and unmeasured outright; `minTagCount` and
`maxTags` predate it and are not being changed, only re-examined - see the distinction below the
table:

| Constant | Current value | What it controls |
|---|---|---|
| `neighbourCount` | 5 | How many candidates stage 1 retrieves per document (the plan's starting `k`). |
| `neighbourRelevanceFloor` | `0` | The `bm25()` cutoff below which a neighbour is shown. SQLite's `bm25()` scores a match negative, more negative meaning a *stronger* match, so a survivor needs `rank < neighbourRelevanceFloor`. **0 admits every row that matched at all** — permissive on purpose, not yet biting, pending a real (more negative) value from the corpus. |
| `visualNeighbourRelevanceFloor` | `.infinity` | Stage 3's own cutoff, same mechanism (`survivingNeighbours(_:floor:)`) applied to Vision `distance(to:)` instead of `bm25()`. Closer to 0 is a stronger match, unbounded above, so `.infinity` admits every candidate - there is no "matched at all" boundary to default to the way bm25 has, so this stays maximally permissive until measured. |
| `minTagCount` | 3 | The global block's frequency cutoff (unchanged; see below). |
| `maxTags` | 30 | The global block's tag-list cap (unchanged; see below). |

`minTagCount` and `maxTags` are stage 2's variant axis, not stage 1's: the hypothesis is that the
global block can shrink now that neighbours carry vocabulary too, freeing prompt budget for the
retrieved examples. The two are not in the same evidential state, though: `maxTags`'s current value
of 30 carries a real recorded measurement (the comment on it — doubling to 60 left tag F1
bit-identical while the model suggested *fewer* tags), while `minTagCount`'s current value of 3 carries
no measurement anywhere in this repository — it is simply what the constant already was before this
feature existed. Neither has been measured against *this* feature's hypothesis, so changing either
without running the corpus first would be an unmeasured regression dressed as progress — both stay
unchanged until the corpus says otherwise.

## Measurement pending

Nothing in this feature has shipped on a measured win yet — the acceptance criterion
(`Tag F1 over EvaluationCorpus is higher than the stage 0 baseline`) requires a corpus run this
repository's current toolchain cannot perform: `ContentExtractionEvaluation` is
`@available(macOS 27, *)` and behind `#if canImport(Evaluations)`, both satisfied only by Xcode 27.
This section is the instruction sheet for running it there.

### 1. Get a corpus

Build one from a folder of already-tagged PDFs. It is kept out of the repository — it carries real
document text:

```
swift run EvalCorpusBuilder <path-to-tagged-pdf-folder> -o corpus.json
```

### 2. Run the baseline you are comparing against

Every run scores `ContentExtractionEvaluation`
(`ArchiverLib/Tests/ContentExtractorStoreTests/ContentExtractionEvaluation.swift`) against that one
corpus:

```
PDF_ARCHIVER_EVAL_CORPUS=$(pwd)/corpus.json swift test --filter ContentExtractionEvaluationTests
```

Its `tagF1` / `tagPrecision` / `tagRecall` metrics are the `TagScore` comparison the acceptance
criterion asks for, aggregated over the corpus and attached to the test result as `aggregates.txt`
(`Attachment.record(result.groupedSummary, …)` in the test — open it from the `.xcresult`, or read it
from the command line with `xcrun xcresulttool get --legacy --path <.xcresult> --id <attachment-id>`).

Record this number **twice**, both before touching any constant:

1. **Retrieval off** — set `ContentExtractionEvaluation.retrievalEnabled = false`, run, record `tagF1`.
   This is the stage 0 baseline restated on today's corpus (no code from this PR changes behaviour
   when retrieval is off).
2. **Retrieval on, defaults** — set it back to `true` (the shipped default), run, record `tagF1` with
   `neighbourCount = 5`, `neighbourRelevanceFloor = 0`, `minTagCount = 3`, `maxTags = 30` unchanged.

If (2) is not above (1), stop — the feature has not earned its complexity yet, and no further sweep
matters until it does.

### 3. Sweep stage 1: `neighbourCount` and `neighbourRelevanceFloor`

Both live in `ArchiverLib/Sources/ContentExtractorStore/ContentExtractionPromptFactory.swift`. Change
one, rebuild, rerun step 2's command, record `tagF1`:

- `neighbourCount`: try 3 and 10 alongside the default 5.
- `neighbourRelevanceFloor`: it starts at `0`, meaning *every* real `bm25()` match is shown (the
  floor is wired but not biting — see the table above for the sign convention). Try a handful of
  increasingly negative values (e.g. `-2`, `-5`, `-10`) to find where excluding weak matches helps
  more than it hurts by excluding real ones.

Keep whichever `(neighbourCount, neighbourRelevanceFloor)` pair maximizes `tagF1`, and leave that
pair as the new constant values.

### 4. Sweep stage 2: `minTagCount` and `maxTags`

Only once step 3 has a chosen pair. Both live in the same file. The hypothesis: neighbours now carry
vocabulary too, so the global block may be able to shrink without losing recall. Try `minTagCount = 1`
and `maxTags` below 30 (e.g. 20), together and separately, against the stage 3-chosen retrieval
settings. Keep a combination only if it raises `tagF1` over step 3's result — this file's own history
already shows a plausible-sounding change (`maxTags = 60`) that measured as a no-op, so guessing here
is exactly what this sweep exists to avoid.

### 5. Stage 3, once 1–2 measure positive

The plan gates stage 3 on stages 1–2 measuring positive; this run implements it anyway; the plan's
gate still applies to whether it *ships enabled*. `ContentExtractionEvaluation` cannot exercise stage
3 yet: `CorpusDocument` (the corpus file format) carries extracted text only, no page image, and a
Vision feature print needs a rasterized page — there is nothing for
`VisualNeighbourFinder.documentFeaturePrints` to compute from a corpus entry. Measuring stage 3 needs
either a real archive (feature prints computed and cached by the running app, as `DocumentProcessor`
already does) or extending `CorpusBuilder`/`CorpusDocument` to also capture a page-1 image — neither
is part of this change. Whichever route measures it, `visualNeighbourRelevanceFloor` is the fifth
knob: like the others it is provisional and permissive by default, so it needs the same kind of
sweep `neighbourRelevanceFloor` gets in step 3, against Vision `distance(to:)` values instead of
`bm25()` scores.

Stage 3's compute-cost figures (~18 ms per feature print, ~3 KB stored, ~2 ms to scan 3000 of them)
are Mac numbers measured on a synthetic A4 page and also need re-measuring on device before they are
load-bearing (`docs/adr/0004-visual-retrieval-is-a-fallback-channel.md`).

### What is and is not verified by this repository's own gate

`CorpusRetrieval` (`ArchiverLib/Tests/ContentExtractorStoreTests/CorpusRetrieval.swift`) — the code
that seeds a database from the corpus and answers the retrieval query `ContentExtractionEvaluation`
calls — compiles and is unit-tested on every machine, Xcode 26 included
(`CorpusRetrievalTests.swift`: bm25 ordering, self-exclusion, a document with no seeded text never
comes back, an unusable query returns no candidates instead of throwing). What is **not** compiled or
tested anywhere but Xcode 27 is `ContentExtractionEvaluation.swift` itself and the few lines in its
`init` that call `CorpusRetrieval` — `#if canImport(Evaluations)` compiles them out entirely on this
toolchain. Read those lines by eye before trusting a run's numbers; nothing here has run them.

## Rejected alternatives

- **MobileCLIP** (an image embedding model): rejected before implementation. Its model licence
  (Apple Machine Learning Research) excludes commercial use and product integration, and a CLIP
  image encoder cannot read a document page at its input resolution regardless — it is built for
  natural photos, not dense text layouts.
- **Semantic text embeddings** (`NLContextualEmbedding`, `NLEmbedding.sentenceEmbedding`): deferred,
  not rejected outright. Adding a second retrieval channel at the same time as lexical (bm25)
  retrieval would make a measured result unattributable to either change. Lexical retrieval ships
  and is measured first; semantic embeddings are a candidate for a later, separately-measured stage.
- **A hand-rolled BM25 (or any other ranking function) over an in-memory index**: rejected outright.
  `documentTexts` already is the index this feature needs, and SQLite's `bm25()` already is the
  ranking — reimplementing either would be maintaining a second copy of something the read model
  already provides for free.

## Known limitations

- **German compounds**: `Jahresabrechnung` and `Abrechnung` are distinct tokens to FTS5 without
  decompounding, so some true matches are missed. Accepted: the terms that actually discriminate one
  sender from another in practice are proper nouns and reference numbers, which are uninflected.
