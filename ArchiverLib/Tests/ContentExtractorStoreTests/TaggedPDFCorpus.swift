//
//  TaggedPDFCorpus.swift
//  ContentExtractorStoreTests
//
//  Loads the ground-truth dataset for the content-extraction evaluation.
//
//  Each tagged PDF in the archive is a reference sample: the filename
//  (`yyyy-mm-dd--specification__tag1_tag2.pdf`) is the expected output the user
//  themselves produced, and the PDF text layer is the input the model sees.
//
//  This file is intentionally free of the `Evaluations`/`FoundationModels`
//  frameworks so it compiles on every toolchain and gives a real compile check
//  of the dataset + metric math even when the Evaluations framework is absent.
//

#if os(macOS)
import Quartz.PDFKit
#else
import PDFKit
#endif
import ArchiverModels
import Foundation

/// The reference output for one document, derived from its filename.
///
/// Used both as `ModelSample.expected` and as the wrapped value of the model's
/// generated output, so the judge and the heuristics compare like with like.
///
/// - Note: If the `Evaluations` framework requires the sample/subject type to be
///   `@Generable`, add `import FoundationModels` and the `@Generable` macro here.
///   `Codable` is the documented hard requirement; `@Generable` is only needed for
///   synthetic generation via `SampleGenerator`, which this evaluation does not use.
struct ExtractedInfo: Codable, Hashable, Sendable {
    var specification: String
    var tags: [String]
}

/// One ground-truth document: the text the model sees + the reference output.
struct TaggedPDFSample: Sendable {
    let document: Document
    let text: String
    let expected: ExtractedInfo
}

/// Loads tagged PDFs into an evaluation corpus.
///
/// Sources, in priority order:
///   1. `PDF_ARCHIVER_EVAL_SAMPLES` environment variable → a directory of tagged
///      PDFs (point this at a copy of your real archive — nothing is committed).
///   2. The target's bundled `Samples/` resource folder (drop a curated set there;
///      `*.pdf` is git-ignored so personal documents are never committed).
enum TaggedPDFCorpus {

    struct Loaded: Sendable {
        /// Full corpus — used as the model's "existing documents" context so it
        /// sees a realistic tag distribution and description style. Derived from
        /// filenames only (no text), so loading does not open every PDF.
        let corpus: [Document]
        /// The curated subset actually scored (deterministic, evenly spread). Only
        /// these PDFs are opened to extract their text layer.
        let samples: [TaggedPDFSample]
        /// Human-readable load report (printed by the test, never silently capped).
        let diagnostics: String
    }

    /// Default number of documents to score. Apple recommends starting at 20–30
    /// focused samples; coverage matters more than raw count.
    static let defaultMaxSamples = 30

    /// How many leading pages to read per PDF — mirrors the production text
    /// extractor (`TextAnalyserDependency.getTextFrom`, first 3 pages).
    static let maxPages = 3

    static func load(maxSamples: Int = defaultMaxSamples) -> Loaded {
        let env = ProcessInfo.processInfo.environment
        let resolvedMax = env["PDF_ARCHIVER_EVAL_MAX"].flatMap(Int.init) ?? maxSamples

        let (directory, sourceLabel) = resolveSourceDirectory(env: env)
        guard let directory else {
            return Loaded(
                corpus: [],
                samples: [],
                diagnostics: """
                No sample source found. Set PDF_ARCHIVER_EVAL_SAMPLES to a \
                directory of tagged PDFs, or drop tagged PDFs into the \
                target's Samples/ folder. Evaluation skipped.
                """
            )
        }

        // Sort by filename (≈ by date, since names start with the date) so both
        // the corpus and the evenly-spread sample selection are deterministic.
        let urls = pdfURLs(in: directory).sorted { $0.lastPathComponent < $1.lastPathComponent }

        // Build the full corpus from filenames only — cheap, opens no PDFs. Each
        // file is a distinct document; only literal filename duplicates are dropped
        // (recurring documents like monthly bills have different dates → kept).
        var corpus: [Document] = []
        var seenFilenames = Set<String>()
        var skippedUnparseable = 0
        var skippedDuplicate = 0

        for url in urls {
            guard let parsed = parseFilename(url.lastPathComponent) else {
                skippedUnparseable += 1
                continue
            }
            guard seenFilenames.insert(url.lastPathComponent).inserted else {
                skippedDuplicate += 1
                continue
            }
            corpus.append(Document(
                id: corpus.count,
                url: url,
                date: parsed.date,
                specification: parsed.specification,
                tags: Set(parsed.tags),
                isTagged: true,
                sizeInBytes: 0,
                downloadStatus: 1
            ))
        }

        // Open PDFs only for the scored subset; skip image-only PDFs (no text layer).
        var samples: [TaggedPDFSample] = []
        var skippedNoText = 0
        for document in evenlySpread(corpus, count: resolvedMax) {
            guard let text = pdfText(at: document.url), !text.isEmpty else {
                skippedNoText += 1
                continue
            }
            samples.append(TaggedPDFSample(
                document: document,
                text: text,
                expected: ExtractedInfo(specification: document.specification,
                                        tags: document.tags.sorted())
            ))
        }

        let diagnostics = """
        Content-extraction dataset
          source:           \(sourceLabel) (\(directory.path))
          PDFs found:        \(urls.count)
          valid corpus:      \(corpus.count)
          scored samples:    \(samples.count) (cap \(resolvedMax))
          skipped — no scheme match: \(skippedUnparseable)
          skipped — no text layer:   \(skippedNoText)
          skipped — duplicate filename: \(skippedDuplicate)
        """

        return Loaded(corpus: corpus, samples: samples, diagnostics: diagnostics)
    }

    // MARK: - Source resolution

    private static func resolveSourceDirectory(env: [String: String]) -> (URL?, String) {
        if let path = env["PDF_ARCHIVER_EVAL_SAMPLES"], !path.isEmpty {
            return (URL(fileURLWithPath: path, isDirectory: true), "PDF_ARCHIVER_EVAL_SAMPLES")
        }
        if let bundled = Bundle.module.url(forResource: "Samples", withExtension: nil) {
            return (bundled, "bundled Samples/")
        }
        return (nil, "none")
    }

    private static func pdfURLs(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory,
                                                              includingPropertiesForKeys: nil,
                                                              options: [.skipsHiddenFiles]) else {
            return []
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension.lowercased() == "pdf" }
    }

    // MARK: - PDF text

    private static func pdfText(at url: URL) -> String? {
        guard let pdf = PDFDocument(url: url) else { return nil }
        var text = ""
        for index in 0 ..< min(pdf.pageCount, maxPages) {
            guard let page = pdf.page(at: index), let content = page.string else { continue }
            text += content
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Filename parsing (synchronous subset of Document.parseFilename)

    /// Parse the archiver naming scheme `yyyy-mm-dd--specification__tag1_tag2.pdf`.
    /// Returns `nil` for files that lack a usable reference (no spec, no tags, or a
    /// placeholder value), so only real ground-truth documents enter the dataset.
    static func parseFilename(_ filename: String) -> (date: Date, specification: String, tags: [String])? {
        let name = filename.lowercased().hasSuffix(".pdf") ? String(filename.dropLast(4)) : filename

        let dateAndRest = name.components(separatedBy: "--")
        guard dateAndRest.count == 2,
              let date = DateFormatter.yyyyMMdd.date(from: dateAndRest[0]) else { return nil }

        let specAndTags = dateAndRest[1].components(separatedBy: "__")
        guard specAndTags.count == 2 else { return nil }

        let specification = specAndTags[0]
        guard !specification.isEmpty,
              !specification.lowercased().hasPrefix(Document.descriptionPlaceholder.lowercased()) else { return nil }

        let tags = specAndTags[1]
            .lowercased()
            .components(separatedBy: "_")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tags.isEmpty,
              !tags.contains(Document.tagPlaceholder.lowercased()) else { return nil }

        return (date, specification, tags)
    }

    // MARK: - Helpers

    /// A stable identity for a reference document, used to dedupe the corpus and to
    /// exclude the held-out document from its own context during evaluation.
    static func referenceKey(specification: String, tags: [String]) -> String {
        specification.lowercased() + "|" + ContentExtractionMetrics.normalize(tags).sorted().joined(separator: ",")
    }

    /// Pick `count` items evenly spread across `items` (preserves order, no RNG) so
    /// the scored subset spans the whole archive rather than clustering by date.
    static func evenlySpread<T>(_ items: [T], count: Int) -> [T] {
        guard count > 0, items.count > count else { return items }
        let step = Double(items.count) / Double(count)
        return (0 ..< count).map { items[Int(Double($0) * step)] }
    }
}

/// Pure, deterministic metric math — reused by the heuristic evaluators.
/// Lives here (toolchain-agnostic) so the scoring logic is compile-checked even
/// without the Evaluations framework.
enum ContentExtractionMetrics {

    /// Normalize tags the same way the feature does (`slugified(withSeparator: "")`),
    /// then lowercase for case-insensitive overlap with the reference.
    static func normalize(_ tags: [String]) -> Set<String> {
        Set(tags
            .map { $0.slugified(withSeparator: "").lowercased() }
            .filter { !$0.isEmpty })
    }

    /// Fraction of reference tags that appear in the generated set (0...1).
    static func recall(generated: [String], expected: [String]) -> Double {
        let exp = normalize(expected)
        guard !exp.isEmpty else { return 1 }
        let gen = normalize(generated)
        return Double(exp.intersection(gen).count) / Double(exp.count)
    }

    /// Fraction of generated tags that are in the reference set (0...1).
    static func precision(generated: [String], expected: [String]) -> Double {
        let gen = normalize(generated)
        guard !gen.isEmpty else { return 0 }
        let exp = normalize(expected)
        return Double(gen.intersection(exp).count) / Double(gen.count)
    }

    /// Jaccard similarity of the two tag sets (0...1).
    static func jaccard(generated: [String], expected: [String]) -> Double {
        let gen = normalize(generated)
        let exp = normalize(expected)
        let union = gen.union(exp)
        guard !union.isEmpty else { return 1 }
        return Double(gen.intersection(exp).count) / Double(union.count)
    }

    /// Whitespace-separated word count of a description.
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
