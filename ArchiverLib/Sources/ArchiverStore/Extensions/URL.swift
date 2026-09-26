//
//  URL.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import Foundation
import Logging
import Shared

extension URL: Log {
    func uniqueId() -> Int? {
        do {
            // The kernel assigns document identifiers lazily, so plain local files fall back to a
            // deterministic path hash - `hashValue` is seeded per process and would not survive a relaunch.
            return try resourceValues(forKeys: [.documentIdentifierKey]).documentIdentifier ?? normalized().path().stableHashValue
        } catch {
            log.error("Error while getting unique document identifier", metadata: ["error": "\(LogRedact.describe(error))"])
            return nil
        }
    }

    /// The one spelling of a file the read model stores.
    ///
    /// `resolvingSymlinksInPath()` only strips a real `/private` prefix while the path exists on
    /// disk, so a folder that has not been created yet would keep it and get a different identity
    /// than the same folder once files land in it - trim the prefix by string instead.
    ///
    /// Measured on-device (iPhone, Debug build, 2026-09-21):
    ///
    /// | Path | `/private`? |
    /// |---|---|
    /// | raw metadata URL `…/Mobile Documents/…/1993/1993-01-25--….pdf` | yes |
    /// | same, after `normalized()` | no |
    /// | iCloud base `…/Mobile Documents/…/Documents/` | yes |
    /// | app-container base `…/Containers/Data/Application/…/Documents/` | no |
    /// | same, after `normalized()` (no-op) | no |
    func normalized() -> URL {
        let standardized = standardizedFileURL
        guard standardized.path().hasPrefix("/private/") else { return standardized }
        let trimmedPath = String(standardized.path().dropFirst("/private".count))
        return URL(fileURLWithPath: trimmedPath, isDirectory: standardized.hasDirectoryPath)
    }

    func fileContentModificationDate() -> Date? {
        do {
            return try resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } catch {
            log.error("Error while getting content modification date", metadata: ["error": "\(LogRedact.describe(error))"])
            return nil
        }
    }

    func filename() -> String? {
         do {
             return try resourceValues(forKeys: [.localizedNameKey]).localizedName
         } catch {
             log.error("Error while getting filename", metadata: ["error": "\(LogRedact.describe(error))"])
             return nil
         }
    }

    func fileCreationDate() -> Date? {
        do {
            return try resourceValues(forKeys: [.creationDateKey]).creationDate
        } catch {
            log.error("Error while getting filename", metadata: ["error": "\(LogRedact.describe(error))"])
            return nil
        }
    }

    /// Whether this URL falls under `base`, comparing the normalized spelling of both sides - the
    /// same file must match regardless of which of the two ever carried a stray `/private` prefix.
    /// Compared with a trailing separator so a sibling folder `Archive2` is never treated as a
    /// child of `Archive`.
    func isUnder(_ base: URL) -> Bool {
        (normalized().path() + "/").hasPrefix(base.normalized().path() + "/")
    }
}
