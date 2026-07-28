//
//  ContentExtractorStoreUnitTests.swift
//  ContentExtractorStoreTests
//
//  Deterministic unit tests for the parts of the content extractor that do NOT
//  need Apple Intelligence:
//    • the prompt factory (instruction segments, stats, truncation)
//    • the result mapper (trim, slugify, tag cap)
//    • the actor's cache / availability orchestration, via injected stubs.
//
//  These run in CI on any machine. The stochastic model behaviour is covered by
//  the Evaluations-based suite in ContentExtractionEvaluation.swift.
//

import ArchiverModels
import Foundation
import Testing

@testable import ContentExtractorStore

// MARK: - Prompt factory (pure, no Apple Intelligence)

@Suite("ContentExtractionPromptFactory")
struct ContentExtractionPromptFactoryTests {

    private func doc(_ specification: String, _ tags: [String], date: Date = Date(timeIntervalSince1970: 0)) -> Document {
        Document.mock(date: date, specification: specification, tags: Set(tags))
    }

    @Test("Tags are frequency-sorted and filtered by minimum count")
    func tagStatsFrequencySortedAndFiltered() throws {
        let documents = [
            doc("a", ["rechnung", "auto", "versicherung"]),
            doc("b", ["rechnung", "auto"]),
            doc("c", ["rechnung", "auto"]),
            doc("d", ["rechnung", "versicherung"])
        ]
        // rechnung: 4, auto: 3, versicherung: 2 — minTagCount is 3.
        let stats = ContentExtractionPromptFactory.documentStats(from: documents)

        #expect(stats.tags.contains("rechnung"))
        #expect(stats.tags.contains("auto"))
        #expect(!stats.tags.contains("versicherung"))

        // Only names are embedded - counts in the prompt would leak into the
        // model's tag suggestions (e.g. "rechnung3").
        #expect(stats.tags.rangeOfCharacter(from: .decimalDigits) == nil)

        // Higher frequency listed first (fails loudly if either is missing).
        let rechnungIndex = try #require(stats.tags.range(of: "rechnung"))
        let autoIndex = try #require(stats.tags.range(of: "auto"))
        #expect(rechnungIndex.lowerBound < autoIndex.lowerBound)
    }

    @Test("Stats are deterministic regardless of input order")
    func tagStatsDeterministic() {
        let base = [
            doc("a", ["rechnung", "auto"]),
            doc("b", ["rechnung", "auto"]),
            doc("c", ["rechnung", "auto"])
        ]
        let reversed = Array(base.reversed())
        #expect(ContentExtractionPromptFactory.documentStats(from: base)
                == ContentExtractionPromptFactory.documentStats(from: reversed))
    }

    @Test("Example descriptions are ordered newest first")
    func specificationsNewestFirst() {
        let documents = [
            doc("older", [], date: Date(timeIntervalSince1970: 100)),
            doc("newest", [], date: Date(timeIntervalSince1970: 300)),
            doc("middle", [], date: Date(timeIntervalSince1970: 200))
        ]
        let stats = ContentExtractionPromptFactory.documentStats(from: documents)
        #expect(stats.specifications == "newest\nmiddle\nolder")
    }

    @Test("Text is truncated to the prompt budget minus the custom prompt")
    func truncationRespectsBudget() {
        let budget = ContentExtractionPromptFactory.promptBudget(contextSize: 4096)
        let text = String(repeating: "x", count: budget + 1000)
        #expect(ContentExtractionPromptFactory.truncatedText(from: text, customPromptLength: 0, budget: budget).count
                == budget)
        #expect(ContentExtractionPromptFactory.truncatedText(from: text, customPromptLength: 1000, budget: budget).count
                == budget - 1000)
        // A custom prompt larger than the whole budget leaves no room for text.
        #expect(ContentExtractionPromptFactory.truncatedText(from: text, customPromptLength: budget + 1, budget: budget).isEmpty)
    }

    @Test("Prompt budget scales with the model's context size")
    func promptBudgetScalesWithContextSize() {
        #expect(ContentExtractionPromptFactory.promptBudget(contextSize: 4096) > 0)
        #expect(ContentExtractionPromptFactory.promptBudget(contextSize: 8192)
                > ContentExtractionPromptFactory.promptBudget(contextSize: 4096))
        // A tiny context window must not produce a negative budget.
        #expect(ContentExtractionPromptFactory.promptBudget(contextSize: 100) == 0)
    }

    @Test("Custom prompt is capped so it always fits the budget")
    func customPromptIsCapped() {
        let long = String(repeating: "y", count: 10_000)
        #expect(ContentExtractionPromptFactory.truncatedCustomPrompt(long)?.count
                == ContentExtractionPromptFactory.maxCustomPromptLength)
        #expect(ContentExtractionPromptFactory.truncatedCustomPrompt("short") == "short")
        #expect(ContentExtractionPromptFactory.truncatedCustomPrompt(nil) == nil)
    }

    @Test("Instruction segments embed the locale and the stats")
    func instructionSegmentsContainContext() {
        let stats = ContentExtractionPromptFactory.documentStats(from: [doc("eine rechnung", ["rechnung", "auto", "haus"])])
        let tagsInstruction = ContentExtractionPromptFactory.tagsInstruction(stats: stats)
        let descriptionInstruction = ContentExtractionPromptFactory.descriptionInstruction(stats: stats, locale: Locale(identifier: "de_DE"))

        #expect(tagsInstruction.contains("existing tags"))
        #expect(descriptionInstruction.contains("de_DE"))
        #expect(descriptionInstruction.contains("DO NOT hallucinate"))
    }
}

// MARK: - Result mapper (pure, no Apple Intelligence)

@Suite("ContentExtractionMapper")
struct ContentExtractionMapperTests {

    @Test("Trims the description and slug-cleans the tags")
    func normalizeTrimsAndSlugifies() {
        let raw = RawDocumentInformation(description: "  Tom Tailor Jeans  ",
                                         tags: ["Tom-Tailor", "Rechnung!", "über"])
        let result = ContentExtractionMapper.normalize(raw)
        #expect(result.specification == "Tom Tailor Jeans")
        #expect(result.tags == ["TomTailor", "Rechnung", "ueber"])
    }

    @Test("Caps the number of tags")
    func normalizeCapsTagCount() {
        let raw = RawDocumentInformation(description: "x", tags: Array(repeating: "tag", count: 25))
        let result = ContentExtractionMapper.normalize(raw)
        #expect(result.tags.count == ContentExtractionMapper.maxTags)
    }

    @Test("Strips echoed usage counts from tags")
    func normalizeStripsEchoedCounts() {
        // The model may echo the usage statistics it saw in older prompts,
        // e.g. "rechnung:3" - slugifying alone would turn that into "rechnung3".
        let raw = RawDocumentInformation(description: "x",
                                         tags: ["rechnung:3", "auto #12", "steuer: 4"])
        let result = ContentExtractionMapper.normalize(raw)
        #expect(result.tags == ["rechnung", "auto", "steuer"])
    }

    @Test("Drops purely numeric and empty tags, keeps digits inside words")
    func normalizeDropsNumericTags() {
        let raw = RawDocumentInformation(description: "x",
                                         tags: ["42", "  ", "co2", "!!!", "rechnung"])
        let result = ContentExtractionMapper.normalize(raw)
        #expect(result.tags == ["co2", "rechnung"])
    }
}

// MARK: - Dataset loader & metric math (pure)

@Suite("TaggedPDFCorpus")
struct TaggedPDFCorpusTests {

    @Test("Parses the archiver naming scheme")
    func parsesValidFilename() throws {
        let parsed = try #require(TaggedPDFCorpus.parseFilename("2024-01-05--tom-tailor-jeans__kleidung_rechnung.pdf"))
        #expect(parsed.specification == "tom-tailor-jeans")
        #expect(parsed.tags == ["kleidung", "rechnung"])
    }

    @Test("Rejects filenames without a usable reference")
    func rejectsInvalidFilenames() {
        // No date, no tags, placeholder description, placeholder tag.
        #expect(TaggedPDFCorpus.parseFilename("not-a-document.pdf") == nil)
        #expect(TaggedPDFCorpus.parseFilename("2024-01-05--only-spec.pdf") == nil)
        #expect(TaggedPDFCorpus.parseFilename("2024-01-05--spec__.pdf") == nil)
        #expect(TaggedPDFCorpus.parseFilename("2024-01-05--\(Document.descriptionPlaceholder)x__rechnung.pdf") == nil)
        #expect(TaggedPDFCorpus.parseFilename("2024-01-05--spec__\(Document.tagPlaceholder.lowercased()).pdf") == nil)
    }

    @Test("Evenly spreads a capped sample across the corpus")
    func evenlySpreadCoversTheRange() {
        let items = Array(0..<100)
        let picked = TaggedPDFCorpus.evenlySpread(items, count: 10)
        #expect(picked.count == 10)
        #expect(picked.first == 0)
        // Spread, not just the first 10.
        #expect(picked.contains { $0 >= 50 })
        // Fewer items than the cap → all returned unchanged.
        #expect(TaggedPDFCorpus.evenlySpread([1, 2, 3], count: 10) == [1, 2, 3])
    }
}

@Suite("ContentExtractionMetrics")
struct ContentExtractionMetricsTests {

    @Test("Recall, precision and Jaccard ignore case, symbols and order")
    func overlapNormalizes() {
        // "Rechnung!" slugifies to "rechnung"; expected has it plus one missing tag.
        #expect(ContentExtractionMetrics.recall(generated: ["Rechnung!", "auto"], expected: ["rechnung", "haus"]) == 0.5)
        #expect(ContentExtractionMetrics.precision(generated: ["rechnung", "xyz"], expected: ["rechnung"]) == 0.5)
        #expect(ContentExtractionMetrics.jaccard(generated: ["a", "b"], expected: ["b", "c"]) == 1.0 / 3.0)
    }

    @Test("Empty generated tags yield zero precision but full recall is guarded")
    func overlapEdgeCases() {
        #expect(ContentExtractionMetrics.precision(generated: [], expected: ["a"]) == 0)
        // No reference tags → recall is defined as 1 (nothing to miss).
        #expect(ContentExtractionMetrics.recall(generated: ["a"], expected: []) == 1)
    }
}

// MARK: - Actor orchestration (needs OS 26 APIs, but NOT a usable model)

private actor CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

// NOTE: ContentExtractorStore is `@available(iOS 26, macOS 26, *)`, but the Swift
// Testing macros refuse `@available`-annotated declarations in this toolchain. So
// the suite/tests stay un-annotated; the OS-26 helpers carry the availability and
// each test body opens an `if #available` window before touching them.
@Suite("ContentExtractorStore orchestration")
struct ContentExtractorStoreOrchestrationTests {

    @available(iOS 26.0, macOS 26.0, *)
    private static func makeCache() -> ContentExtractorCache {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return ContentExtractorCache(cacheDirectory: directory)
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func store(availability: AppleIntelligenceAvailability = .available,
                              respond: @escaping ContentExtractorStore.Responder) -> ContentExtractorStore {
        ContentExtractorStore(cache: makeCache(), availability: { availability }, respond: respond)
    }

    @Test("Maps and normalizes the raw model output")
    func mapsRawOutput() async throws {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let store = Self.store { _, _, _ in
            RawDocumentInformation(description: "  Tom Tailor Jeans  ", tags: ["Tom-Tailor", "Rechnung!", "kleidung"])
        }
        let info = try #require(try await store.extract(from: "text", with: []))
        #expect(info.specification == "Tom Tailor Jeans")
        #expect(info.tags == ["TomTailor", "Rechnung", "kleidung"])
    }

    @Test("Returns nil and does not call the model when unavailable")
    func returnsNilWhenUnavailable() async throws {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let store = Self.store(availability: .unavailable) { _, _, _ in
            Issue.record("Responder must not be called when the model is unavailable")
            return RawDocumentInformation(description: "", tags: [])
        }
        let info = try await store.extract(from: "text", with: [])
        #expect(info == nil)
    }

    @Test("Caches the result per document ID")
    func cachesPerDocumentId() async throws {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let counter = CallCounter()
        let store = Self.store { _, _, _ in
            await counter.increment()
            return RawDocumentInformation(description: "desc", tags: ["tag"])
        }

        let first = try await store.extract(from: "text", with: [], documentId: 42)
        let second = try await store.extract(from: "text", with: [], documentId: 42)

        #expect(first == second)
        #expect(await counter.count == 1, "Second call for the same document ID should be served from cache")
    }

    @Test("Calls the model every time when no document ID is given")
    func noCachingWithoutDocumentId() async throws {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let counter = CallCounter()
        let store = Self.store { _, _, _ in
            await counter.increment()
            return RawDocumentInformation(description: "desc", tags: ["tag"])
        }

        _ = try await store.extract(from: "text", with: [])
        _ = try await store.extract(from: "text", with: [])

        #expect(await counter.count == 2)
    }

    @Test("Disabling the cache bypasses it even with a document ID")
    func disablingCacheBypassesIt() async throws {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let counter = CallCounter()
        let store = Self.store { _, _, _ in
            await counter.increment()
            return RawDocumentInformation(description: "desc", tags: ["tag"])
        }
        await store.setCacheEnabled(false)

        _ = try await store.extract(from: "text", with: [], documentId: 7)
        _ = try await store.extract(from: "text", with: [], documentId: 7)

        #expect(await counter.count == 2)
    }
}
