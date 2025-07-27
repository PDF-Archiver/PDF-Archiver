//
//  URL.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import Foundation
import Shared

extension URL: Log {
    func uniqueId() -> Int? {
        do {
            // we use the path hashValue as a backup
            return try resourceValues(forKeys: [.documentIdentifierKey]).documentIdentifier ?? path().hashValue
        } catch {
            log.error("Error while getting unique document identifier", metadata: ["error": "\(error)"])
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

    func securityScope<T>(closure: (URL) throws -> T) rethrows -> T {
        let didAccessSecurityScope = startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                stopAccessingSecurityScopedResource()
            }
        }
        return try closure(self)
    }
}
