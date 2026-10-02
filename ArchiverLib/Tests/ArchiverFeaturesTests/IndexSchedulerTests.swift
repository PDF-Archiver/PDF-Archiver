//
//  IndexSchedulerTests.swift
//  ArchiverLib
//

import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Dependencies
import DependenciesTestSupport
import DocumentProcessingPipeline
import Foundation
import Shared
import SQLiteData
import Testing

@testable import ArchiverFeatures

@Suite(.dependencies { try $0.bootstrapDatabase() })
struct IndexSchedulerTests {
    /// The background task is the only pass that ran OCR and the AI cache over the whole archive,
    /// so an app that stays open used to make no progress on documents already on the device.
    @Test(.timeLimit(.minutes(1)))
    func theForegroundLoopAlsoRunsTheProcessingPass() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try Document.insert {
                Document.mock(url: URL(fileURLWithPath: "/archive/untagged/scan1.pdf"), isTagged: false, downloadStatus: 1)
            }
            .execute(db)
        }

        let processed = AsyncStream<[Document]>.makeStream()
        let loop = Task {
            await withDependencies {
                $0.archiveIndexer.pendingTextCount = { 0 }
                $0.documentProcessor.processUntaggedDocuments = { documents in
                    processed.continuation.yield(documents)
                    return UntaggedProcessingResult(ocrCount: 0, aiCacheCount: 0)
                }
            } operation: {
                await IndexSchedulerDependency.liveValue.indexWhileAppIsOpen()
            }
        }
        defer { loop.cancel() }

        var rounds = processed.stream.makeAsyncIterator()
        let documents = await rounds.next()

        #expect(documents?.count == 1)
    }

    /// The background task used to be the only caller of the prefetch, so on macOS, which has no
    /// background task, the index never got past the documents that happened to be on the device.
    @Test(.timeLimit(.minutes(1)))
    func theForegroundLoopRequestsDownloadsOnceNothingIsPending() async throws {
        @Dependency(\.defaultDatabase) var database
        let remoteURL = URL(fileURLWithPath: "/archive/2024/remote.pdf")
        try await database.write { db in
            try Document.insert {
                Document.mock(url: remoteURL, isTagged: true, downloadStatus: 0)
            }
            .execute(db)
        }

        let requestedURLs = AsyncStream<URL>.makeStream()
        let loop = Task {
            await withDependencies {
                $0.defaultAppStorage = .inMemory
                $0.archiveIndexer.pendingTextCount = { 0 }
                $0.premium.currentStatus = { .active }
                $0.networkPath.allowsAutomaticDownloads = { true }
                $0.archiveStore.startDownloadOf = { url in requestedURLs.continuation.yield(url) }
                $0.documentProcessor.processUntaggedDocuments = { _ in
                    UntaggedProcessingResult(ocrCount: 0, aiCacheCount: 0)
                }
            } operation: {
                await IndexSchedulerDependency.liveValue.indexWhileAppIsOpen()
            }
        }
        defer { loop.cancel() }

        var requests = requestedURLs.stream.makeAsyncIterator()
        #expect(await requests.next() == remoteURL)
    }

    /// The OCR and AI-cache pass has no budget, and the AI half retries its failures on every
    /// pass, so a pass can outlast the process - it must not hold the text index back meanwhile.
    @Test(.timeLimit(.minutes(1)))
    func aProcessingPassThatNeverReturnsDoesNotBlockTheForegroundTextIndex() async throws {
        try await Self.insertAnUntaggedDocument()
        let indexedBudgets = AsyncStream<Int>.makeStream()
        let loop = Task {
            await withDependencies {
                $0.archiveIndexer.pendingTextCount = { 1 }
                $0.archiveIndexer.indexPendingTexts = { budget in
                    indexedBudgets.continuation.yield(budget)
                    return []
                }
                $0.premium.currentStatus = { .active }
                $0.documentProcessor.processUntaggedDocuments = { _ in await Self.neverReturningPass() }
            } operation: {
                await IndexSchedulerDependency.liveValue.indexWhileAppIsOpen()
            }
        }
        defer { loop.cancel() }

        var budgets = indexedBudgets.stream.makeAsyncIterator()
        #expect(await budgets.next() == 10)
    }

    @Test(.timeLimit(.minutes(1)))
    func aProcessingPassThatNeverReturnsDoesNotBlockTheBackgroundTextIndex() async throws {
        try await Self.insertAnUntaggedDocument()
        let indexedBudgets = AsyncStream<Int>.makeStream()
        let run = Task {
            try await withDependencies {
                $0.archiveStore.reloadDocuments = { }
                $0.archiveIndexer.waitWhileReconciling = { _ in true }
                $0.archiveIndexer.indexPendingTexts = { budget in
                    indexedBudgets.continuation.yield(budget)
                    return []
                }
                $0.premium.currentStatus = { .active }
                $0.documentProcessor.processUntaggedDocuments = { _ in await Self.neverReturningPass() }
            } operation: {
                try await runBackgroundProcessing(runningPhases: LockIsolated([]))
            }
        }
        defer { run.cancel() }

        var budgets = indexedBudgets.stream.makeAsyncIterator()
        #expect(await budgets.next() == 250)
    }

    /// The gate reads the same check as the rest of the app, which counts only the premium
    /// products - any other verified entitlement used to open it.
    @Test
    func theTextIndexGateFollowsThePremiumStatus() async {
        let isActive = await withDependencies {
            $0.premium.currentStatus = { .active }
        } operation: {
            await PremiumEntitlement.isActive()
        }

        #expect(isActive)
    }

    /// The processing pass only runs when the inbox or the AI context holds a document.
    private static func insertAnUntaggedDocument() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try Document.insert {
                Document.mock(url: URL(fileURLWithPath: "/archive/untagged/scan1.pdf"), isTagged: false, downloadStatus: 1)
            }
            .execute(db)
        }
    }

    private static func neverReturningPass() async -> UntaggedProcessingResult {
        // Returns only once the test cancels the loop or the run around it.
        try? await Task<Never, Never>.never()
        return UntaggedProcessingResult(ocrCount: 0, aiCacheCount: 0)
    }
}

struct BackgroundTaskCompletionTests {
    /// The run and the watchdog can both finish, and `setTaskCompleted` must be called only once.
    @Test
    func aSecondCompletionIsIgnored() async {
        let completions = LockIsolated<[Bool]>([])
        let completion = BackgroundTaskCompletion { success in
            completions.withValue { $0.append(success) }
        }

        await completion.complete(success: true, completion: "normal")
        await completion.complete(success: false, completion: "watchdog")

        #expect(completions.value == [true])
    }

    /// A run that outlives its expiration used to leave the task open: the watchdog checked
    /// `isCancelled` right after cancelling, which is always true.
    @Test(.timeLimit(.minutes(1)))
    func theWatchdogCompletesATaskFiveSecondsAfterItExpired() async {
        let clock = TestClock()
        let completions = LockIsolated<[Bool]>([])
        let completion = BackgroundTaskCompletion { success in
            completions.withValue { $0.append(success) }
        }

        let watchdog = Task {
            await withDependencies {
                $0.continuousClock = clock
            } operation: {
                await completion.completeAfterGracePeriod()
            }
        }
        await clock.advance(by: .seconds(4))
        #expect(completions.value.isEmpty)

        await clock.advance(by: .seconds(1))
        await watchdog.value
        #expect(completions.value == [false])
    }
}

@Suite(.dependencies { try $0.bootstrapDatabase() })
struct EvictLocalCopiesTests {
    /// No storage chosen is the default iCloud archive, which the storage type alone never said.
    @Test
    func evictsArchiveDocumentsButKeepsUntagged() async {
        let evictedURLs = LockIsolated<[URL]>([])
        await withDependencies {
            $0.defaultAppStorage = .inMemory
            $0.archiveStore.evictDocumentAt = { url in evictedURLs.withValue { $0.append(url) } }
        } operation: {
            await evictLocalCopies(of: [
                Document.mock(url: URL(fileURLWithPath: "/archive/2024/tagged.pdf"), isTagged: true, downloadStatus: 1),
                Document.mock(url: URL(fileURLWithPath: "/archive/untagged/inbox.pdf"), isTagged: false, downloadStatus: 1)
            ], evictsIndexedDocuments: true)
        }

        #expect(evictedURLs.value == [URL(fileURLWithPath: "/archive/2024/tagged.pdf")])
    }

    /// A Mac keeps what it indexed: its disk is not the scarce resource an iPhone's is.
    @Test
    func keepsEveryDocumentWhereIndexedDocumentsStayLocal() async {
        let evictedCount = LockIsolated(0)
        await withDependencies {
            $0.defaultAppStorage = .inMemory
            $0.archiveStore.evictDocumentAt = { _ in evictedCount.withValue { $0 += 1 } }
        } operation: {
            await evictLocalCopies(of: [Document.mock(isTagged: true, downloadStatus: 1)], evictsIndexedDocuments: false)
        }

        #expect(evictedCount.value == 0)
    }

    @Test
    func skipsEvictionWhenDownloadAllForSearchIsOff() async {
        let evictedCount = LockIsolated(0)
        await withDependencies {
            $0.defaultAppStorage = .inMemory
            $0.archiveStore.evictDocumentAt = { _ in evictedCount.withValue { $0 += 1 } }
        } operation: {
            @Shared(.downloadAllForSearch) var downloadAllForSearch: Bool
            $downloadAllForSearch.withLock { $0 = false }

            await evictLocalCopies(of: [Document.mock(isTagged: true, downloadStatus: 1)], evictsIndexedDocuments: true)
        }

        #expect(evictedCount.value == 0)
    }
}
