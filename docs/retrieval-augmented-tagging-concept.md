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

Nothing below is measured yet. Every constant lives in
`ArchiverLib/Sources/ContentExtractorStore/ContentExtractionPromptFactory.swift`, with a doc comment
marking it provisional, so re-tuning never means hunting through the call sites:

| Constant | Current value | What it controls |
|---|---|---|
| `neighbourCount` | 5 | How many candidates stage 1 retrieves per document (the plan's starting `k`). |
| `neighbourRelevanceFloor` | `0` | The `bm25()` cutoff below which a neighbour is shown. SQLite's `bm25()` scores a match negative, more negative meaning a *stronger* match, so a survivor needs `rank < neighbourRelevanceFloor`. **0 admits every row that matched at all** — permissive on purpose, not yet biting, pending a real (more negative) value from the corpus. |
| `minTagCount` | 3 | The global block's frequency cutoff (unchanged; see below). |
| `maxTags` | 30 | The global block's tag-list cap (unchanged; see below). |

`minTagCount` and `maxTags` are stage 2's variant axis, not stage 1's: the hypothesis is that the
global block can shrink now that neighbours carry vocabulary too, freeing prompt budget for the
retrieved examples. That is exactly the kind of claim this file's own history warns against
guessing — the comment on `maxTags` already records that doubling it to 60 left tag F1
bit-identical while the model suggested *fewer* tags. Changing either constant without measuring the
result against the stage 0 baseline would be an unmeasured regression dressed as progress, so both
stay at their last measured values until the corpus says otherwise.

## Measurement pending

Nothing in this feature has shipped on a measured win yet — the acceptance criterion
(`Tag F1 over EvaluationCorpus is higher than the stage 0 baseline`) requires a corpus run this
machine cannot perform: `ContentExtractionEvaluation` is `@available(macOS 27, *)` and behind
`#if canImport(Evaluations)`, and this repository's current toolchain is Xcode 26.

To measure a variant, on a machine with Xcode 27 and the `Evaluations` framework:

1. Build a corpus from a folder of already-tagged PDFs (kept out of the repository — it carries real
   document text):
   ```
   swift run EvalCorpusBuilder <path-to-tagged-pdf-folder> -o corpus.json
   ```
2. Point the evaluation at it and run it:
   ```
   PDF_ARCHIVER_EVAL_CORPUS=$(pwd)/corpus.json swift test --filter ContentExtractionEvaluationTests
   ```
   This scores `ContentExtractionEvaluation` (`ArchiverLib/Tests/ContentExtractorStoreTests/ContentExtractionEvaluation.swift`),
   whose `tagF1` / `tagPrecision` / `tagRecall` metrics are exactly the `TagScore` comparison the
   acceptance criterion asks for, aggregated over the corpus and attached as `aggregates.txt`.
3. Repeat per variant (a `neighbourCount` / `neighbourRelevanceFloor` combination, then a
   `minTagCount` / `maxTags` combination once stage 1 has a chosen `k` and floor), recording each
   variant's `tagF1` against the stage 0 baseline before choosing one to ship.

**Known gap:** `ContentExtractionEvaluation` constructs `ContentExtractorStore()` with its defaults,
which leaves `neighbourFinder` and `visualNeighbourFinder` at `.unavailable` — the corpus dataset is
an in-memory array of `CorpusDocument`, not a live SQLite `documentTexts` index, so today's harness
does not exercise retrieval at all. Measuring stages 1–3 needs the evaluation wired to a real (or
temporary, in-memory) `ArchiverDatabase` so `NeighbourFinder.documentTexts` has something to query
against the corpus's own documents. That wiring is not part of this change; see the PR's follow-ups.

Stage 3's compute-cost figures (~18 ms per feature print, ~3 KB stored, ~2 ms to scan 3000 of them)
are Mac numbers measured on a synthetic A4 page and also need re-measuring on device before they are
load-bearing (`docs/adr/0004-visual-retrieval-is-a-fallback-channel.md`).

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
