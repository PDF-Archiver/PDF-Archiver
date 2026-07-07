//
//  ContentExtractionEvaluation.swift
//  ContentExtractorStoreTests
//
//  Evaluates ContentExtractorStore.extract(from:with:) — the Apple Intelligence
//  feature that turns a PDF's text into a short description and a set of tags.
//
//  Ground truth comes from the user's own tagged PDFs: the filename is the
//  reference output, the text layer is the input. See TaggedPDFCorpus.swift.
//
//  Requirements to RUN (the suite self-skips otherwise):
//    • Xcode 27+ with the Evaluations framework (`#if canImport(Evaluations)`).
//    • A device/Mac whose OS provides the Evaluations + FoundationModels runtime,
//      with Apple Intelligence available.
//    • A sample source (PDF_ARCHIVER_EVAL_SAMPLES env var or bundled Samples/).
//    • Run in the locale your documents are in — the feature picks its output
//      locale from Locale.current.region (German archive → run with a DE region).
//
//  This is a LOCAL, on-device evaluation for hill-climbing the prompt. It is kept
//  in the test plan but self-skips on CI (no Apple Intelligence, no samples).
//

#if canImport(Evaluations)

import ArchiverModels
import ContentExtractorStore
import Evaluations
import FoundationModels
import Testing

@available(macOS 27.0, iOS 27.0, *)
struct ContentExtractionEvaluation: Evaluation {

    typealias Sample = ModelSample<ExtractedInfo>

    // MARK: Dataset & context

    /// Full corpus, used as the model's "existing documents" context.
    let corpus: [Document]
    let dataset: ArrayLoader<Sample>

    init(loaded: TaggedPDFCorpus.Loaded) {
        self.corpus = loaded.corpus
        self.dataset = ArrayLoader(samples: loaded.samples.map { sample in
            Sample(prompt: sample.text, expected: sample.expected)
        })
    }

    // MARK: Subject — run the real feature

    func subject(from sample: Sample) async throws -> ModelSubject<ExtractedInfo> {
        // Feed the model the user's other documents as context, but exclude this
        // document so its own answer can't leak through the example descriptions.
        let targetKey: String? = sample.expected.map {
            TaggedPDFCorpus.referenceKey(specification: $0.specification, tags: $0.tags)
        }
        let context = corpus.filter { doc in
            TaggedPDFCorpus.referenceKey(specification: doc.specification, tags: Array(doc.tags)) != targetKey
        }

        let store = ContentExtractorStore()
        // documentId: nil → bypass the cache so every run reflects the current prompt.
        let info = try await store.extract(from: sample.promptDescription, with: context, documentId: nil)

        // A nil result means the model declined/was unavailable for this sample;
        // represent it as empty output so the heuristics score it as a real miss.
        return ModelSubject(value: ExtractedInfo(specification: info?.specification ?? "",
                                                 tags: info?.tags ?? []))
    }

    // MARK: Quantitative metrics (heuristics)

    let tagFormatValid = Metric("Tag format valid")                 // gate
    let forbiddenContent = Metric("No forbidden content")           // gate
    let descriptionLengthValid = Metric("Description length valid") // gate
    let nonEmptyRate = Metric("Produced non-empty output")          // observe
    let tagLowercaseRate = Metric("Tags lowercase")                 // observe
    let tagCountRaw = Metric("Tag count")                           // observe
    let descriptionWordCountRaw = Metric("Description word count")  // observe
    let tagRecall = Metric("Tag recall vs reference")               // observe
    let tagPrecision = Metric("Tag precision vs reference")         // observe
    let tagJaccard = Metric("Tag Jaccard vs reference")             // observe

    // MARK: Qualitative dimensions (model judge)

    let tagRelevance = ScoreDimension(
        "Tag relevance",
        description: """
            Whether the generated tags correctly categorize THIS document (vendor, \
            document type, topic) the way a user would file it — judged against how \
            the same user tagged this very document.
            """,
        scale: .numeric([
            4: "Every tag accurately categorizes the document; together they match how it should be filed.",
            3: "Most tags fit; at most one is too generic or slightly off.",
            2: "Some tags fit, but several are irrelevant, redundant, or mislabel the document.",
            1: "Tags largely fail to describe the document or contradict its content."
        ])
    )

    let descriptionGroundedness = ScoreDimension(
        "Description groundedness",
        description: """
            Whether every fact in the description (names, vendors, amounts, dates, \
            document type) is actually supported by the document text. This measures \
            hallucination — the feature's prime directive is to never invent content.
            """,
        scale: .numeric([
            4: "Fully supported by the text; nothing invented.",
            3: "Supported with only minor vagueness; no fabricated facts.",
            2: "Mostly grounded but includes at least one detail absent from the text.",
            1: "Contains hallucinated facts (names, amounts, vendors) not in the document."
        ])
    )

    let descriptionStyleFit = ScoreDimension(
        "Description style fit",
        description: """
            Whether the description matches the user's own naming style: a short \
            (≈3–10 word) factual label in the document's language, like the reference \
            description — not a full sentence, not the wrong language, not empty when \
            the document clearly has content.
            """,
        scale: .numeric([
            4: "Concise, right language, clearly modeled on the user's reference style.",
            3: "Reasonable label with minor style deviation (slightly long, wording differs).",
            2: "Understandable but off-style (too long, wrong language, or sentence-like).",
            1: "Does not resemble the user's naming style at all, or empty for a contentful document."
        ])
    )

    var evaluators: Evaluators {
        // — Tag structure (code-enforced guarantees) —
        Evaluator { _, subject in
            let tags = subject.value.tags
            if tags.count > 10 {
                return tagFormatValid.failing(rationale: "\(tags.count) tags (> 10)")
            }
            if let bad = tags.first(where: { $0.isEmpty || $0 != $0.slugified(withSeparator: "") }) {
                return tagFormatValid.failing(rationale: "Non-slug tag: '\(bad)'")
            }
            return tagFormatValid.passing(rationale: "\(tags.count) tags, all slug-clean")
        }
        Evaluator { _, subject in
            let tags = subject.value.tags
            guard !tags.isEmpty else { return tagLowercaseRate.passing(rationale: "no tags") }
            if let upper = tags.first(where: { $0 != $0.lowercased() }) {
                return tagLowercaseRate.failing(rationale: "Tag not lowercase: '\(upper)'")
            }
            return tagLowercaseRate.passing()
        }
        Evaluator { _, subject in
            tagCountRaw.scoring(Double(subject.value.tags.count))
        }

        // — Forbidden content (echoes, placeholders, junk) —
        Evaluator { _, subject in
            let spec = subject.value.specification
            let tags = subject.value.tags
            if spec.lowercased().hasPrefix(Document.descriptionPlaceholder.lowercased()) {
                return forbiddenContent.failing(rationale: "Description is the temp placeholder")
            }
            if tags.contains(where: { $0.lowercased() == Document.tagPlaceholder.lowercased() }) {
                return forbiddenContent.failing(rationale: "Placeholder tag present")
            }
            if let junk = tags.first(where: { $0.count > 30 }) {
                return forbiddenContent.failing(rationale: "Tag looks like echoed text: '\(junk)'")
            }
            if spec.count > 200 {
                return forbiddenContent.failing(rationale: "Description \(spec.count) chars — likely echoing input")
            }
            return forbiddenContent.passing()
        }

        // — Description length / presence —
        Evaluator { _, subject in
            let spec = subject.value.specification
            if spec.isEmpty {
                return descriptionLengthValid.passing(rationale: "empty (model declined to extract)")
            }
            let words = ContentExtractionMetrics.wordCount(spec)
            return words <= 12
                ? descriptionLengthValid.passing(rationale: "\(words) words")
                : descriptionLengthValid.failing(rationale: "\(words) words (> 12)")
        }
        Evaluator { _, subject in
            descriptionWordCountRaw.scoring(Double(ContentExtractionMetrics.wordCount(subject.value.specification)))
        }
        Evaluator { _, subject in
            let hasOutput = !subject.value.specification.isEmpty && !subject.value.tags.isEmpty
            return hasOutput
                ? nonEmptyRate.passing()
                : nonEmptyRate.failing(rationale: "empty description and/or no tags")
        }

        // — Reference overlap (observability; synonyms keep strict overlap low) —
        Evaluator { sample, subject in
            tagRecall.scoring(ContentExtractionMetrics.recall(generated: subject.value.tags,
                                                              expected: sample.expected?.tags ?? []))
        }
        Evaluator { sample, subject in
            tagPrecision.scoring(ContentExtractionMetrics.precision(generated: subject.value.tags,
                                                                    expected: sample.expected?.tags ?? []))
        }
        Evaluator { sample, subject in
            tagJaccard.scoring(ContentExtractionMetrics.jaccard(generated: subject.value.tags,
                                                                expected: sample.expected?.tags ?? []))
        }

        // — Qualitative judge —
        // Judge model should be >= the feature model. The feature uses the on-device
        // SystemLanguageModel; for a stronger judge (recommended once you have it)
        // swap in a Private Cloud Compute model here.
        ModelJudgeEvaluator(
            judge: SystemLanguageModel.default,
            dimensions: [tagRelevance, descriptionGroundedness, descriptionStyleFit],
            prompt: ModelJudgePrompt<Sample>(
                instructions: """
                    You are evaluating the description and tags automatically generated for \
                    PDF Archiver, a personal document-archiving app. Users file scanned \
                    documents — invoices, contracts, letters, receipts, often in German — \
                    under a short description and a set of lowercase tags, then find them \
                    later by browsing and searching those tags.

                    A good result lets the user instantly recognize the document and find it \
                    again. Tags should categorize the document (vendor, document type, topic) \
                    the way the user already files similar documents. The description should \
                    be a short, factual label grounded only in the document text — never \
                    invented. Documents may be in German; judge German output on its own terms.
                    """,
                evaluationTarget: { value in
                    """
                    Description: \(value.specification.isEmpty ? "<empty>" : value.specification)
                    Tags: \(value.tags.isEmpty ? "<none>" : value.tags.joined(separator: ", "))
                    """
                },
                reference: { input, _ in
                    [
                        "Document text (model input)": String(input.promptDescription.prefix(2000)),
                        "Reference description (how the user named this file)": input.expected?.specification ?? "n/a",
                        "Reference tags (the user's own tags for this file)": input.expected?.tags.joined(separator: ", ") ?? "n/a"
                    ]
                }
            )
        )
    }

    // MARK: Aggregation

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.group("Tag structure") { group in
            group.computeMean(of: tagFormatValid)
            group.computeMean(of: tagLowercaseRate)
            group.computeMean(of: tagCountRaw)
            group.computeStandardDeviation(of: tagCountRaw)
        }
        aggregator.group("Output presence") { group in
            group.computeMean(of: forbiddenContent)
            group.computeMean(of: descriptionLengthValid)
            group.computeMean(of: nonEmptyRate)
            group.computeMean(of: descriptionWordCountRaw)
            group.computeStandardDeviation(of: descriptionWordCountRaw)
        }
        aggregator.group("Reference overlap") { group in
            group.computeMean(of: tagRecall)
            group.computeStandardDeviation(of: tagRecall)
            group.computeMean(of: tagPrecision)
            group.computeMean(of: tagJaccard)
        }
        aggregator.group("Quality (judge)") { group in
            group.computeMean(of: tagRelevance.metric)
            group.computeMean(of: descriptionGroundedness.metric)
            group.computeMean(of: descriptionStyleFit.metric)
            group.computeStandardDeviation(of: descriptionGroundedness.metric)
        }
    }
}

// MARK: - Test suite

// ============================================================================
// WHY THIS DOESN'T USE THE `.evaluates(...)` TRAIT  (read before changing it)
// ============================================================================
//
// The idiomatic way to run an `Evaluation` is the Swift Testing trait:
//
//     @Test("…", .evaluates(evaluation, info: info))
//
// which is what wires the run into Xcode's **Evaluations report tab** (aggregate
// charts + per-sample table with judge rationales) and the **Compare view** for
// hill-climbing. We CANNOT use it here, because three things collide:
//
//   1. The whole Evaluations API — including `.evaluates` — is macOS/iOS **27**
//      only (`@available(anyAppleOS 27.0)`).
//   2. This package deploys to **macOS 15 / iOS 18** (for the shipping app), and
//      SPM has no per-target deployment override, so this test target is 15/18 too.
//   3. The Swift Testing `@Test`/`@Suite` macros **refuse** an `@available`-narrowed
//      declaration ("Attribute 'Test' cannot be applied … marked '@available'").
//
// So: without `@available` the 27-only symbols don't type-check; with `@available`
// the macro rejects the test. Verified empirically (direct attribute AND via an
// `@available` extension — both fail). Therefore the test below stays un-annotated
// and drives the evaluation manually with `evaluation.run(info:)` inside an
// `if #available(macOS 27, …)` window. Correctness + the `#expect` gates are fully
// preserved; only the Xcode report/Compare UI is missing.
//
// ----------------------------------------------------------------------------
// TO GET THE FULL XCODE INTEGRATION WHEN YOU RUN UNDER macOS / iOS 27
// ----------------------------------------------------------------------------
//
// Requirement first: the eval code must be compiled with a **deployment target of
// macOS 27 / iOS 27** so no `@available` is needed (that's what unblocks the macro).
// Pick ONE:
//
//   (A) RECOMMENDED — move this evaluation into its own SPM package/target that
//       declares `platforms: [.macOS(.v27), .iOS(.v27)]` and depends on
//       ContentExtractorStore. Keeps the app's 15/18 floor untouched.
//   (B) Only if the app itself moves to 27: raise `platforms` in ArchiverLib's
//       Package.swift to `.macOS(.v27) / .iOS(.v26)…` — do NOT do this just for
//       the eval; it would drop older-OS users.
//
// Then, once the deployment target is 27, REPLACE the `ContentExtractionEvaluationTests`
// suite below with the trait form (delete the `run()` body + the `if #available`):
//
//     @Suite("Content Extraction Evaluation")
//     struct ContentExtractionEvaluationTests {
//         static let loaded = TaggedPDFCorpus.load()
//         static let evaluation = ContentExtractionEvaluation(loaded: loaded)
//         static let info: [String: String] = [ /* same metadata as below */ ]
//         static var canRun: Bool {
//             loaded.samples.count >= 5 && ContentExtractorStore.getAvailability().isUsable
//         }
//
//         @Test("Content extraction quality", .enabled(if: canRun), .evaluates(evaluation, info: info))
//         func evaluateContentExtraction() async throws {
//             let result = EvaluationContext.current.result          // populated by the trait
//             #expect(result.aggregateValue(.mean(of: Self.evaluation.tagFormatValid)) >= 0.99)
//             #expect(result.aggregateValue(.mean(of: Self.evaluation.forbiddenContent)) >= 0.99)
//             #expect(result.aggregateValue(.mean(of: Self.evaluation.descriptionLengthValid)) >= 0.9)
//             #expect(result.aggregateValue(.mean(of: Self.evaluation.tagRelevance.metric)) >= 3.0)
//             #expect(result.aggregateValue(.mean(of: Self.evaluation.descriptionGroundedness.metric)) >= 3.25)
//         }
//     }
//
// The `ContentExtractionEvaluation` struct itself needs NO change (drop its
// `@available(macOS 27 …)` once the deployment target is 27, but leaving it is
// harmless). Run via Xcode (not `swift test`) to see the Evaluations report tab.
//
// NOTE: the `run()` form below ALSO works fine under macOS 27 — switching is purely
// to gain the Xcode UI. If you only want the pass/fail gates, leave this as-is.
// ============================================================================

@Suite("Content Extraction Evaluation")
struct ContentExtractionEvaluationTests {

    static let loaded = TaggedPDFCorpus.load()

    /// Run metadata so runs stay attributable when comparing hill-climbing
    /// iterations. Bump these when you change the prompt/model.
    static let info: [String: String] = [
        "Feature": "ContentExtractorStore.extract — description + tags from PDF text",
        "Model": "SystemLanguageModel.default (on-device)",
        "Judge": "SystemLanguageModel.default",
        "Samples": "\(loaded.samples.count)",
        "Notes": "Baseline. Change one variable per run."
    ]

    /// Skip cleanly unless we actually have data and an available model.
    static var canRun: Bool {
        guard loaded.samples.count >= 5 else { return false }
        guard #available(macOS 26.0, iOS 26.0, *) else { return false }
        return ContentExtractorStore.getAvailability().isUsable
    }

    @Test("Content extraction quality", .enabled(if: canRun))
    func evaluateContentExtraction() async throws {
        guard #available(macOS 27.0, iOS 27.0, *) else { return }

        print(Self.loaded.diagnostics)

        let evaluation = ContentExtractionEvaluation(loaded: Self.loaded)
        let result = try await evaluation.run(info: Self.info)

        // Aggregate numbers + per-dimension means; read the judge rationales in
        // `result.detailed` to decide the next prompt change.
        print(result.groupedSummary)

        // —— Optimization targets (gates) ——
        // Thresholds are starting points; raise them as the feature hill-climbs.

        // Format is code-enforced (slugified, <=10 tags) → must be ~perfect.
        #expect(result.aggregateValue(.mean(of: evaluation.tagFormatValid)) >= 0.99)

        // Echoed input / placeholders are always-wrong outputs.
        #expect(result.aggregateValue(.mean(of: evaluation.forbiddenContent)) >= 0.99)

        // Descriptions must stay label-length (the prompt asks for 5–10 words).
        #expect(result.aggregateValue(.mean(of: evaluation.descriptionLengthValid)) >= 0.9)

        // Tags should be useful categorizations of the document (judge, 1–4 scale).
        #expect(result.aggregateValue(.mean(of: evaluation.tagRelevance.metric)) >= 3.0)

        // Hallucination is the worst failure mode → strictest gate.
        #expect(result.aggregateValue(.mean(of: evaluation.descriptionGroundedness.metric)) >= 3.25)

        // Everything else (recall/precision/Jaccard, word-count distribution, style
        // fit, lowercase rate) is observability — inspect `result.detailed`.
    }
}

#endif
