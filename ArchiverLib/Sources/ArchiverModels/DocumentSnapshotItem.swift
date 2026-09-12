//
//  DocumentSnapshotItem.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 06.09.26.
//

import Foundation

/// One file of a folder snapshot, as `ArchiveStore` hands it to the indexer.
///
/// Public so the producer (`ArchiverStore`) and the consumer (`ArchiverDatabase`) can share it:
/// `ArchiverStore` depends on `ArchiverDatabase`, so passing the store-internal
/// `DocumentInformation` across would be a module cycle.
nonisolated public struct DocumentSnapshotItem: Equatable, Sendable {
    public let id: Document.ID
    /// Normalised: `standardizedFileURL.resolvingSymlinksInPath()`.
    public let url: URL
    /// Folder membership *and* filename pattern, decided by `ArchiveStore`.
    public let isTagged: Bool
    public let sizeInBytes: Double
    public let downloadStatus: Double
    /// Date fallback for untagged files whose filename carries none.
    public let creationDate: Date?
    public let contentModificationDate: Date?

    public init(id: Document.ID,
                url: URL,
                isTagged: Bool,
                sizeInBytes: Double,
                downloadStatus: Double,
                creationDate: Date?,
                contentModificationDate: Date?) {
        self.id = id
        self.url = url
        self.isTagged = isTagged
        self.sizeInBytes = sizeInBytes
        self.downloadStatus = downloadStatus
        self.creationDate = creationDate?.truncatedToStoredPrecision()
        self.contentModificationDate = contentModificationDate?.truncatedToStoredPrecision()
    }
}

extension Date {
    /// The value the `TEXT` date columns round-trip: whole seconds plus milliseconds, built in the
    /// reference-date domain `Date` itself stores. Scaling `timeIntervalSince1970` instead lands
    /// just under the millisecond, the ISO-8601 encoder then writes the previous one, and the
    /// snapshot never equals the row again - which is what made every snapshot rewrite every row.
    nonisolated func truncatedToStoredPrecision() -> Date {
        let seconds = timeIntervalSinceReferenceDate.rounded(.down)
        let milliseconds = ((timeIntervalSinceReferenceDate - seconds) * 1000).rounded(.down)
        return Date(timeIntervalSinceReferenceDate: seconds + milliseconds / 1000)
    }
}

extension Document {
    /// The row one snapshot item becomes: the filename decides date, specification and tags, with
    /// the file's creation date as the fallback for an untagged scan.
    public static func make(from item: DocumentSnapshotItem, rootKey: String) async -> Document {
        let filename = item.url.lastPathComponent
        let parsed = await parseFilename(filename)
        var specification = parsed.specification ?? ""
        if item.isTagged {
            specification = specification.replacing("-", with: " ")
        }

        return Document(id: item.id,
                        rootKey: rootKey,
                        url: item.url,
                        filename: filename,
                        date: parsed.date ?? item.creationDate ?? Date(),
                        specification: specification,
                        tags: Set(parsed.tagNames ?? []),
                        isTagged: item.isTagged,
                        sizeInBytes: item.sizeInBytes,
                        downloadStatus: item.downloadStatus,
                        contentModificationDate: item.contentModificationDate)
    }
}

extension String {
    /// A deterministic 64-bit FNV-1a hash, used as the document id when the file system has not
    /// assigned a `documentIdentifier`.
    ///
    /// `hashValue` is seeded per process, so a row written by one launch would never match the
    /// same file in the next one.
    nonisolated public var stableHashValue: Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x1000_0000_01b3
        }
        return Int(bitPattern: UInt(truncatingIfNeeded: hash))
    }
}
