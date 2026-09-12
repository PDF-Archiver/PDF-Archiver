//
//  URL.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import Foundation
import Shared

extension URL: Log {
    func uniqueId() -> Int? {
        do {
            // The kernel assigns document identifiers lazily, so plain local files fall back to a
            // deterministic path hash - `hashValue` is seeded per process and would not survive a relaunch.
            return try resourceValues(forKeys: [.documentIdentifierKey]).documentIdentifier ?? normalized().path().stableHashValue
        } catch {
            log.error("Error while getting unique document identifier", metadata: ["error": "\(error)"])
            return nil
        }
    }

    /// The one spelling of a file the read model stores.
    func normalized() -> URL {
        standardizedFileURL.resolvingSymlinksInPath()
    }

    func fileContentModificationDate() -> Date? {
        do {
            return try resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } catch {
            log.error("Error while getting content modification date", metadata: ["error": "\(error)"])
            return nil
        }
    }

    func filename() -> String? {
         do {
             return try resourceValues(forKeys: [.localizedNameKey]).localizedName
         } catch {
             log.error("Error while getting filename", metadata: ["error": "\(error)"])
             return nil
         }
    }

    func fileCreationDate() -> Date? {
        do {
            return try resourceValues(forKeys: [.creationDateKey]).creationDate
        } catch {
            log.error("Error while getting filename", metadata: ["error": "\(error)"])
            return nil
        }
    }
}
