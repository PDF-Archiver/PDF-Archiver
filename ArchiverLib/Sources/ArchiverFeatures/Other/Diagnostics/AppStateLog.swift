import ArchiverDatabase
import ArchiverModels
import ComposableArchitecture
import Foundation
import OSLog
import Shared
import SQLiteData

/// The baseline a support report starts from: what the archive holds, where it lives and which of
/// the optional features are on. Logged at `notice`, the lowest level OSLog keeps long enough for
/// a report written later to still find it.
enum AppStateLog {
    static func log() async {
        let metadata = await snapshot()
        Logger.app.notice("App state", metadata: metadata)
    }

    /// Split from `log()` because OSLog's own output is not observable from a test.
    static func snapshot() async -> [String: String] {
        @Dependency(\.defaultDatabase) var database
        @Dependency(\.archiveIndexer) var archiveIndexer
        @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .loading
        @Shared(.appleIntelligenceEnabled) var appleIntelligenceEnabled: Bool
        @Shared(.downloadAllForSearch) var downloadAllForSearch: Bool
        @Shared(.ocrEnabled) var ocrEnabled: Bool
        @SharedReader(.archivePathType) var archivePathType: StorageType?

        let counts = await withErrorReporting {
            try await database.read { db in
                (total: try Document.all.fetchCount(db),
                 untagged: try Document.where { !$0.isTagged }.fetchCount(db),
                 notDownloaded: try Document.where { $0.downloadStatus.lt(1) }.fetchCount(db))
            }
        }

        return [
            "storage": storageName(archivePathType),
            "documentCount": "\(counts?.total ?? -1)",
            "untaggedCount": "\(counts?.untagged ?? -1)",
            "notDownloadedCount": "\(counts?.notDownloaded ?? -1)",
            "pendingTextCount": "\(await archiveIndexer.pendingTextCount())",
            "premiumStatus": premiumStatus.rawValue,
            "downloadAllForSearch": "\(downloadAllForSearch)",
            "appleIntelligenceEnabled": "\(appleIntelligenceEnabled)",
            "ocrEnabled": "\(ocrEnabled)"
        ]
    }

    /// A custom folder's URL is the user's own path, so only the kind of storage is reported.
    static func storageName(_ storage: StorageType?) -> String {
        guard let storage else { return "none" }
        switch storage {
        case .iCloudDrive:
            return "iCloudDrive"

        #if !os(macOS)
        case .appContainer:
            return "appContainer"
        #endif

        case .local:
            return "local"
        }
    }
}
