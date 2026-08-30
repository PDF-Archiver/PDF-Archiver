# Content extraction evaluations

Hill-climbs the description and tag suggestions of `ContentExtractorStore`
against documents that are already filed: the filename is the ground truth, and
the prompt never gets to see it.

Needs **macOS 27** (the Evaluations framework). The sources live in
`ArchiverLib/Tests/ContentExtractorStoreTests`, next to the unit tests of the
feature they measure; this folder holds only the Xcode project that runs them
inside a signed host.

## 1. Build the corpus

Copy filed PDFs into one folder - they must follow the archive convention
`yyyy-mm-dd--description__tag1_tag2.pdf`, because that is where the expected
answers come from. Then:

```bash
swift run --package-path ArchiverLib EvalCorpusBuilder <pdf-folder> -o <corpus.json>
```

The tool reports what it skipped and how the corpus splits. Documents without a
complete date/description/tags triple, or without a usable text layer, are left
out - the app would not offer suggestions for them either.

The corpus holds the text of real documents. Keep it out of the repository.

## 2. Run the evaluations

Everything is driven by environment variables; nothing has a default path, so a
machine without a corpus skips the evaluations instead of failing them.

| Variable | Meaning |
|---|---|
| `PDF_ARCHIVER_EVAL_CORPUS` | The corpus file. Unset - the evaluations skip. |
| `PDF_ARCHIVER_EVAL_PAGES` | Pre-rendered page images (see below). Unset - samples run on text alone. |

**From the package** - fast, on-device judge, no signing:

```bash
export PDF_ARCHIVER_EVAL_CORPUS=/path/to/corpus.json
swift test --package-path ArchiverLib --filter ContentExtraction
```

**From the workspace** - Private Cloud Compute and the Xcode report:

```bash
xcodebuild test -workspace PDFArchiver.xcworkspace -scheme Evaluations \
                -destination 'platform=macOS'
```

Set the variables in the scheme's test environment (Product > Scheme > Edit
Scheme > Test > Arguments) - `xcodebuild` does not forward shell variables into a
hosted test process.

Results land in the test report's **Evaluations** tab. Two suites run: the
heuristics (tag F1, vocabulary reuse, description length against the archive's
own band, tag count, safety) and a model judge for style, groundedness and tag
granularity.

### Why a host app

Entitlements belong to a *process*, not to a loadable bundle. Run hostless, the
tests execute inside Apple's `xctest` binary and the Private Cloud Compute
request traps; hosted, they run in an app signed with
`com.apple.developer.private-cloud-compute`. `swift test` cannot do this at all -
its bundles are ad-hoc signed. The host is deliberately **not** sandboxed,
because the corpus lives outside any container.

That entitlement is *managed*: granted per team through
<https://developer.apple.com/contact/request/private-cloud-compute/> and carried
by a provisioning profile. Nothing reports it missing up front - `availability`
and `contextSize` both answer normally, and only the first request fails, via
`fatalError`, taking the test process with it. Hence `CloudComputeEntitlement`,
which checks the running bundle before the judge sends anything. Without the
grant the judge suite skips and the heuristics still gate.

## 3. Hill-climb

The prompt lives in `ContentExtractionPromptFactory`; an iteration is an edit to
that file. Change **one** thing, run again, and use **Compare** in the report -
the run metadata carries the full instruction text, so a comparison always shows
which prompt produced which numbers. When a change is kept, raise the `#expect`
thresholds so a later regression fails the test.

### What has been tried

Kept:

- **Description length derived from the archive.** The prompt asked for "5-10
  words" where this archive uses 1-4, and answers piled up on 5.
- **Tags must be supported by the document.** "Ordered by most frequently used
  first" invited the model to sprinkle frequent tags onto documents that had
  none.
- **Twice as many example descriptions** (20 -> 40), with the character cap that
  truncated them mid-word removed. It moved the *tags*: that block is the only
  place the model sees the archive's own wording.
- **Tag co-occurrence pairs from the archive.** Roughly half of all filed tags
  never appear in the document text, so no wording reaches them - but they follow
  reliably from the tags that do. The one change that reached that class.
- **The archive vocabulary enforced in the store**, and **a description may not
  repeat a chosen tag** (prompt-side, because word overlap also matches good
  answers). Both cost tag agreement and were kept anyway.

Rejected, with numbers, so nobody repeats them:

- **More tags offered** (30 -> 45): tag F1 0.400 -> 0.374. **Fewer** (30 -> 20):
  0.368. A longer list does not raise recall - the model picks *fewer* from it.
- **Tag count from the archive**: its 10th/90th percentile is already what the
  prompt asks for.
- **Example descriptions as filed slugs** rather than the space-separated form:
  tag F1 0.417 -> 0.408.
- **Demanding the issuer in the description**: length conformance 1.00 -> 0.48,
  tag F1 0.427 -> 0.302. Groundedness did rise, so a wording that adds the issuer
  without adding length is the open idea here.
- **The vocabulary rule in the prompt** instead of the store: tag F1 0.417 ->
  0.340, complied on 54% of documents. The deterministic filter reaches 0.92.

### Measurement traps

- **The on-device model is not deterministic.** Observed spread on identical
  prompts: tag F1 0.025. Private Cloud Compute reproduces bit-identically; the
  on-device model differs in half its outputs despite `sampling: .greedy`.
- **The on-device judge is generous** - about 0.3-0.4 above Private Cloud Compute
  on identical suggestions. Climb against the cloud judge.
- **A metric that cannot see an effect reports a clean zero**, and a strawman
  input proves nothing: the heuristics never score content, and the page image
  beat filler text dramatically and real document text not at all.
- **A dropped sample is a missing measurement, not a failure.** The judge's
  4096-token window has to hold document, reference and answer; check
  `evaluatorFailureCount` when a mean moves unexpectedly.
- **The ceiling on tags is not the prompt.** Half the filed tags are family
  names, filing conventions and judgement calls that no document states. With
  recall capped near 0.51, tag F1 cannot exceed ~0.67 however it is worded.

### Private Cloud Compute for the extraction itself

Measured, not adopted - the app deliberately keeps documents on device. Render
the pages once, point the variable at them, and flip one flag:

```bash
xcrun swift Evaluations/prerender-pages.swift <archive-root> <corpus.json> <output-folder>
export PDF_ARCHIVER_EVAL_PAGES=<output-folder>
```

```swift
// ArchiverLib/Tests/ContentExtractorStoreTests/ContentExtractionEvaluation.swift
static let usesCloudCompute = true
```

Rendering inside the test bundle hangs - the signed host needs a TCC grant to
read the archive that a headless run can never ask for - hence the separate
script.

| Model | Text | Page image | Tag F1 | Recall |
|---|---|---|---|---|
| on-device | 4750 chars | no | 0.423-0.448 | 0.370-0.394 |
| on-device | 4750 chars | yes | 0.435 | 0.377 |
| Private Cloud Compute | 4750 chars | no | 0.486 | 0.457 |
| Private Cloud Compute | whole document | no | 0.486 | 0.457 |
| Private Cloud Compute | whole document | yes | **0.521** | **0.506** |

The gain is the model and the image, not the window: only 3 of 26 samples exceed
4750 characters. The image helps the cloud model only - presumably because layout
is what a flat text layer loses.

## Results

26 samples, 306 context documents, on-device model and on-device judge.

| | baseline | optimized |
|---|---|---|
| Tag F1 | 0.435 | 0.423-0.448 |
| Tag recall | 0.483 | 0.370-0.394 |
| Tags from archive vocabulary | 0.48 | 1.00 |
| Description length matches archive band | 0.32 | 1.00 |
| Description word count | 4.84 | 2.19 (band 1-4) |
| Suggestion offered | 0.96 | 1.00 |
| Tag count in requested range | 0.96 | 1.00 |
| Style / groundedness / granularity | 3.44 / 3.24 / 3.44 | 3.69 / 3.54 / 3.65 |

Tag F1 is flat by design: the vocabulary filter trades recall for precision, and
no invented tag reaches the user any more. Everything the user actually sees -
length, count, vocabulary, whether a suggestion arrives at all - is at 1.00.
