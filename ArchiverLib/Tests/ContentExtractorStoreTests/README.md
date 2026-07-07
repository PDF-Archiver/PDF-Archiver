# ContentExtractorStore evaluation

Evaluation-driven development for the Apple Intelligence document tagger
(`ContentExtractorStore.extract(from:with:)`), built on Apple's **Evaluations**
framework (Xcode 27+). It measures the generated *description* and *tags* against
your own tagged PDFs as ground truth.

## How it works

| Part | Where it comes from |
|------|---------------------|
| Input (prompt) | First 3 pages of the PDF's text layer |
| Expected output | Parsed from the filename `yyyy-mm-dd--description__tag1_tag2.pdf` |
| Context | Your *other* tagged documents (the held-out doc is excluded to avoid leakage) |
| Feature under test | The real `ContentExtractorStore`, cache bypassed |

## Prerequisites

- Xcode 27+ (provides the `Evaluations` framework — the suite compiles to nothing
  without it via `#if canImport(Evaluations)`).
- A Mac/device on macOS 26 / iOS 26 with **Apple Intelligence available**.
- Sample data (see `Samples/README.md`) — env var or bundled folder.
- Run in the **locale of your documents**: the feature reads `Locale.current.region`
  to pick its output language (German archive → run with a `de_DE` / DE region).

The suite **self-skips** (`.enabled(if:)`) when there are fewer than 5 samples or
the model is unavailable, so it is harmless on any machine and in CI.

## Running

In Xcode (recommended — you get the rich Evaluations report + Compare view):

1. Set `PDF_ARCHIVER_EVAL_SAMPLES` in the test scheme's environment, or drop PDFs
   into `Samples/`.
2. Run the `Content Extraction Evaluation` suite.
3. Report navigator → **Evaluations** tab: aggregate charts on top, per-sample rows
   below. Select a row to read the model's full output **and the judge rationales** —
   that is the primary debugging surface.

From the command line (pass/fail only, no report):

```sh
PDF_ARCHIVER_EVAL_SAMPLES=/path/to/pdfs \
  swift test --filter ContentExtractionEvaluationTests
```

> Not part of `ArchiverLib.xctestplan` on purpose — CI has no Apple Intelligence.

## What it measures

**Gates** (`#expect`, the optimization targets):

| Metric | Target | Why |
|--------|--------|-----|
| Tag format valid | ≥ 0.99 | slugified, ≤ 10 tags — code-enforced, catches regressions |
| No forbidden content | ≥ 0.99 | no echoed input, placeholders, or junk tags |
| Description length valid | ≥ 0.90 | stays a label (≤ 12 words) |
| Tag relevance (judge 1–4) | ≥ 3.0 | tags actually categorize the document |
| Description groundedness (judge 1–4) | ≥ 3.25 | **no hallucination** — strictest gate |

**Observability** (in the report, not gated — read these to decide the next change):
tag recall / precision / Jaccard vs. your reference tags, tag-count and word-count
distributions, lowercase rate, description style fit.

Strict tag overlap is intentionally *not* gated: synonyms ("invoice" vs. "rechnung")
make exact match noisy, so semantic tag quality is gated via the judge instead while
overlap stays as a trend to watch.

## Hill-climbing from here

1. **Read judge rationales** first — one real run beats hours of planning.
2. Change **one variable per run** (prompt wording, tag-count instruction, example
   count in `createSession`, the model). Bump `info[...]` so Xcode's Compare view can
   attribute runs.
3. **Calibrate the judge** before trusting it at scale: export a run's
   `.xcevalresult`, score ~20 samples yourself, and add a calibration evaluation
   whose `subject(from:)` returns the stored outputs (no live call) so judge and you
   rate identical data. Gate Cohen's kappa per dimension at `> 0.6`
   (`group.custom(of:label:)`). A ready-made `cohensKappa` ships with the skill.
4. **Grow the dataset** with `SampleGenerator` once 20–30 curated samples pass but
   you want more coverage; validate generated samples against the naming scheme.
5. Consider a **stronger judge** (`PrivateCloudComputeLanguageModel()`) — Apple's
   guidance is that the judge be at least as capable as the feature model.
