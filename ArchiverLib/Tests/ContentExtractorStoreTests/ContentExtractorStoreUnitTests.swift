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
//  These run in CI on any machine.
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
        #expect(ContentExtractionPromptFactory.truncatedCustomPrompt(long, maxLength: 500)?.count == 500)
        #expect(ContentExtractionPromptFactory.truncatedCustomPrompt("short", maxLength: 500) == "short")
        #expect(ContentExtractionPromptFactory.truncatedCustomPrompt(nil, maxLength: 500) == nil)
    }

    @Test("Custom prompt cap grows with the model's context size")
    func customPromptCapScalesWithContextSize() {
        #expect(ContentExtractionPromptFactory.maxCustomPromptLength(contextSize: 4096) == 1024)
        #expect(ContentExtractionPromptFactory.maxCustomPromptLength(contextSize: 8192) == 3072)
    }

    @Test("Custom prompt cap never falls below the static default")
    func customPromptCapHasFloor() {
        #expect(ContentExtractionPromptFactory.maxCustomPromptLength(contextSize: 100)
                == ContentExtractionPromptFactory.defaultMaxCustomPromptLength)
    }

    @Test("Custom prompt never claims more than a quarter of the budget")
    func customPromptCapLeavesRoomForText() {
        let contextSize = 8192
        let budget = ContentExtractionPromptFactory.promptBudget(contextSize: contextSize)
        let cap = ContentExtractionPromptFactory.maxCustomPromptLength(contextSize: contextSize)
        #expect(ContentExtractionPromptFactory.truncatedText(from: String(repeating: "x", count: 100_000),
                                                            customPromptLength: cap,
                                                            budget: budget).count == budget - cap)
        #expect(cap * 4 <= budget)
    }

    @Test("Instruction segments embed the locale and the stats")
    func instructionSegmentsContainContext() {
        let stats = ContentExtractionPromptFactory.documentStats(from: [doc("eine rechnung", ["rechnung", "auto", "haus"])])
        let tagsInstruction = ContentExtractionPromptFactory.tagsInstruction(stats: stats, locale: Locale(identifier: "de_DE"))
        let descriptionInstruction = ContentExtractionPromptFactory.descriptionInstruction(stats: stats, locale: Locale(identifier: "de_DE"))

        #expect(tagsInstruction.contains("existing tags"))
        #expect(descriptionInstruction.contains("de_DE"))
        #expect(descriptionInstruction.contains("DO NOT hallucinate"))
    }

    @Test("Tags instruction embeds the locale")
    func tagsInstructionContainsLocale() {
        let stats = ContentExtractionPromptFactory.documentStats(from: [doc("eine rechnung", ["rechnung", "auto", "haus"])])
        let instruction = ContentExtractionPromptFactory.tagsInstruction(stats: stats, locale: Locale(identifier: "de_DE"))

        #expect(instruction.contains("de_DE"))
    }

    @Test("Tags instruction without existing tags has no dangling colon but keeps the rules")
    func tagsInstructionWithoutExistingTags() {
        let stats = ContentExtractionPromptFactory.documentStats(from: [doc("eine rechnung", ["rechnung"])])
        #expect(stats.tags.isEmpty)

        let instruction = ContentExtractionPromptFactory.tagsInstruction(stats: stats, locale: Locale(identifier: "de_DE"))

        #expect(!instruction.contains("most frequently used first"))
        #expect(!instruction.contains(":\n"))
        #expect(!instruction.hasSuffix(":"))

        #expect(instruction.contains("create new appropriate tags"))
        #expect(instruction.contains("de_DE"))
        #expect(instruction.contains("single lowercase word"))
        #expect(instruction.contains("2-4 tags"))
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
        #expect(result.tags == ["tomtailor", "rechnung", "ueber"])
    }

    @Test("Lowercases the tags")
    func normalizeLowercasesTags() {
        let raw = RawDocumentInformation(description: "x", tags: ["Rechnung", "AUTO", "Über"])
        let result = ContentExtractionMapper.normalize(raw)
        #expect(result.tags == ["rechnung", "auto", "ueber"])
    }

    @Test("Deduplicates tags stably and keeps the model's order")
    func normalizeDeduplicatesStably() {
        let raw = RawDocumentInformation(description: "x",
                                         tags: ["rechnung", "auto", "Rechnung", "Tom-Tailor", "auto", "tom tailor"])
        let result = ContentExtractionMapper.normalize(raw)
        #expect(result.tags == ["rechnung", "auto", "tomtailor"])
    }

    @Test("Caps the number of tags")
    func normalizeCapsTagCount() {
        let raw = RawDocumentInformation(description: "x", tags: (0..<25).map { "tag\($0)" })
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
        #expect(info.tags == ["tomtailor", "rechnung", "kleidung"])
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

    @Test("Disabling the cache also stops writing new entries")
    func disablingCacheStopsWrites() async throws {
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        let store = Self.store { _, _, _ in
            RawDocumentInformation(description: "desc", tags: ["tag"])
        }
        await store.setCacheEnabled(false)

        _ = try await store.extract(from: "text", with: [], documentId: 7)

        #expect(await store.getCacheCount() == 0)
    }
}
