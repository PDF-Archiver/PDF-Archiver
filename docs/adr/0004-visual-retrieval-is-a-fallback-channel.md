# 0004 — Visual retrieval is a fallback channel, never the primary one

**Status:** accepted, 2026-09-14 — ships alongside the bm25 text retrieval it falls back from
(`docs/retrieval-augmented-tagging-concept.md`).

## Context

Stage 1 ranks already-tagged documents by `bm25(documentTexts)` and offers the model the best
matches as few-shot examples. That signal is strong wherever it exists, because the extracted text
is strictly richer than any global image descriptor. It does not exist everywhere: a photo of a
receipt, thermal paper, or a skewed scan can leave OCR with too little text for any neighbour to
clear `ContentExtractionPromptFactory.neighbourRelevanceFloor`, and the model is left with only the
generic global block again — exactly the case retrieval was meant to improve on.

## Decision

`GenerateImageFeaturePrintRequest` (Vision, `.revision2`) produces 768 floats describing layout
gestalt — letterhead position, column grid, table blocks — with no notion of what the page says.
That is worth having only where text retrieval fails, so it is wired as a fallback, not a second
source added on top: `ContentExtractorStore` calls it only when stage 1 finds nothing above the
floor, never alongside a text match.

- `PDFOCREngine.firstPageFeaturePrint(of:)` rasterizes page 1 and requests the print with
  `cropAndScaleAction = .scaleToFit` (a centre crop would remove the letterhead) and
  `regionOfInterest` restricted to the top third, where the sender identity sits and the varying
  body text does not.
- It rasterizes independently of the OCR text-layer pass: an untagged document that already carries
  a text layer skips that pass entirely, so the print cannot simply ride along with it.
- `ContentExtractorStore` holds this behind the same kind of seam as the text channel
  (`VisualNeighbourFinder`, alongside `NeighbourFinder`), so the module stays free of both Vision
  and `ArchiverDatabase`.

## Consequences

- A new table, `documentFeaturePrints` (`DocumentFeaturePrint`), joins the read model
  (`docs/adr/0003-database-is-a-derived-read-model.md`): derived, droppable, rebuilt like every
  other table.
- `FeaturePrintObservation` has no public initializer that rebuilds one from its raw vector alone,
  so an entry stores the whole `Codable` round trip (`PropertyListEncoder`), not just
  `observation.data`.
- `distance(to:)` throws across `GenerateImageFeaturePrintRequest.Revision` values, so every entry
  is stamped with `FeaturePrintCache.currentRevision` and a mismatched entry is treated as a cache
  miss and recomputed, never surfaced to the user.
- No vector index: a linear scan plus `distance(to:)` over the tagged archive is cheap enough
  (measured at ~2 ms for 3000 prints, Mac numbers on synthetic input — see the concept doc's
  measurement-pending section) that one is not warranted yet.
- The floor exists on this channel too, not only the text one: `ContentExtractionPromptFactory.visualNeighbourRelevanceFloor`
  is filtered through the same `survivingNeighbours(_:floor:)` the text channel uses, so a weak
  visual match cannot bypass the "wrong vocabulary is worse than none" rule just because it arrived
  through the fallback path. Permissive by default (`.infinity`) — a feature-print distance has no
  natural "matched at all" boundary the way `bm25()` does, so there is no principled default to pick
  ahead of measurement.
- `DocumentProcessor`'s untagged-processing pass also backfills feature prints for *tagged*
  documents (bounded to `DocumentProcessor.taggedFeaturePrintBackfillBudget` per call): the visual
  channel reads only tagged rows (`DocumentFeaturePrint.taggedRows`), so without a backfill every
  document tagged before this shipped would never get a print and the channel would stay inert for
  the whole existing archive. The bound keeps one background pass from turning into thousands of
  Vision calls on a large archive; the rest catch up on subsequent passes.

## Alternatives considered

- **MobileCLIP**, rejected before implementation: its model licence (Apple Machine Learning
  Research) excludes commercial use and product integration, and a CLIP image encoder cannot read a
  document page at its input resolution regardless. Vision's feature print is the on-device
  equivalent that already ships in the SDK.
