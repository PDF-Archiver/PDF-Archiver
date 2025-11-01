//
//  ContentExtractorCache.swift
//  ArchiverLib
//
//  Created by Claude on 31.10.25.
//

import ArchiverModels
import CryptoKit
import Foundation
import OSLog
import Shared

/// Manages caching of content extraction results to improve performance
/// Only used internally by ContentExtractorStore
@available(iOS 26, macOS 26, *)
actor ContentExtractorCache: Log {

    // MARK: - Types

    struct CacheEntry: Codable, Sendable {
        let documentId: Document.ID
        let specification: String
        let tags: [String]

        init(documentId: Document.ID, specification: String, tags: [String]) {
            self.documentId = documentId
            self.specification = specification
            self.tags = tags
        }
    }

    // MARK: - Properties

    private let cacheDirectory: URL
    private var isEnabled: Bool

    // MARK: - Initialization

    init(cacheDirectory: URL? = nil, isEnabled: Bool = true) {
        // Use app's cache directory by default (system can remove if needed)
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            self.cacheDirectory = URL.cachesDirectory.appendingPathComponent("ContentExtractor", isDirectory: true)
        }
        self.isEnabled = isEnabled

        // Create cache directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        } catch {
            Logger.contentExtractor.error("Failed to create cache directory: \(error)")
        }
    }

    // MARK: - Internal Methods

    /// Get cached result for a document by ID
    /// - Parameter documentId: The unique identifier of the document
    /// - Returns: The cached entry if found and valid, nil otherwise
    func getCachedResult(for documentId: Document.ID) -> CacheEntry? {
        guard isEnabled else { return nil }

        let cacheURL = cacheFileURL(for: documentId)

        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let entry = try JSONDecoder().decode(CacheEntry.self, from: data)

            // Verify the cached entry is for the same document
            guard entry.documentId == documentId else {
                Logger.contentExtractor.warning("Cache entry mismatch for document ID: \(documentId)")
                return nil
            }

            return entry
        } catch {
            Logger.contentExtractor.error("Failed to read cache entry for document ID \(documentId): \(error)")
            return nil
        }
    }

    /// Save extraction result to cache
    /// - Parameter entry: The cache entry to save
    func saveCacheEntry(_ entry: CacheEntry) {
        guard isEnabled else { return }

        let cacheURL = cacheFileURL(for: entry.documentId)

        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: cacheURL, options: .atomic)
            Logger.contentExtractor.debug("Cache entry saved for document ID: \(entry.documentId)")
        } catch {
            Logger.contentExtractor.error("Failed to save cache entry for document ID \(entry.documentId): \(error)")
        }
    }

    /// Clear all cache entries
    func clearCache() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                       includingPropertiesForKeys: nil)
            for fileURL in contents {
                try FileManager.default.removeItem(at: fileURL)
            }
            Logger.contentExtractor.info("Cache cleared successfully")
        } catch {
            Logger.contentExtractor.error("Failed to clear cache: \(error)")
        }
    }

    /// Get the number of cache entries
    /// - Returns: The count of cached entries
    func getCacheCount() -> Int {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                       includingPropertiesForKeys: nil)
            return contents.count
        } catch {
            Logger.contentExtractor.error("Failed to get cache count: \(error)")
            return 0
        }
    }

    /// Get all cached document IDs
    /// - Returns: Set of document IDs that have cache entries
    func getCachedDocumentIds() -> Set<Document.ID> {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                       includingPropertiesForKeys: nil)
            var ids = Set<Document.ID>()
            for fileURL in contents {
                if let entry = try? JSONDecoder().decode(CacheEntry.self, from: Data(contentsOf: fileURL)) {
                    ids.insert(entry.documentId)
                }
            }
            return ids
        } catch {
            Logger.contentExtractor.error("Failed to get cached document IDs: \(error)")
            return []
        }
    }

    /// Remove cache entries that don't have matching documents in the provided set
    /// - Parameter validIds: Set of valid document IDs to keep
    func pruneCache(keepingOnly validIds: Set<Document.ID>) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                       includingPropertiesForKeys: nil)
            for fileURL in contents {
                if let entry = try? JSONDecoder().decode(CacheEntry.self, from: Data(contentsOf: fileURL)),
                   !validIds.contains(entry.documentId) {
                    try? FileManager.default.removeItem(at: fileURL)
                    Logger.contentExtractor.debug("Pruned cache entry for document ID: \(entry.documentId)")
                }
            }
        } catch {
            Logger.contentExtractor.error("Failed to prune cache: \(error)")
        }
    }

    /// Update cache enabled state
    /// - Parameter enabled: Whether the cache should be enabled
    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }

    // MARK: - Private Methods

    /// Generate cache file URL for a document ID
    /// - Parameter documentId: The document ID to generate a cache file URL for
    /// - Returns: URL for the cache file with format `<documentId>.json`
    private func cacheFileURL(for documentId: Document.ID) -> URL {
        // Use document ID directly as filename (Int is unique and safe for filesystem)
        return cacheDirectory.appendingPathComponent("\(documentId).json")
    }
}
