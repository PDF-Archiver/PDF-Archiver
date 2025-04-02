//
//  Url.swift
//  
//
//  Created by Julian Kahnert on 29.11.19.
//

import Foundation

// Source Code from: https://github.com/amyspark/xattr
extension URL: Log {

    private static let itemUserTagsName = "com.apple.metadata:_kMDItemUserTags"

    func securityScope<T>(closure: (URL) throws -> T) rethrows -> T {
        let didAccessSecurityScope = startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                stopAccessingSecurityScopedResource()
            }
        }
        return try closure(self)
    }

    func uniqueId() -> Int? {
        do {
            return try resourceValues(forKeys: [.documentIdentifierKey]).documentIdentifier
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

    func setFileTags(_ tags: [String]) {
        do {
            #if os(macOS)
            // https://stackoverflow.com/a/47340666
            try (self as NSURL).setResourceValue(tags, forKey: URLResourceKey.tagNamesKey)
            #else
            try setiOSFileTags(tags)
            #endif
        } catch {
            log.error("Error while setting tag names", metadata: ["error": "\(error)"])
        }
    }

    // MARK: - iOS finder tags

    private func setiOSFileTags(_ fileTags: [String]) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: fileTags, requiringSecureCoding: false)
        try setExtendedAttribute(data: data, forName: URL.itemUserTagsName)
    }

    /// Set extended attribute.
    private func setExtendedAttribute(data: Data, forName name: String, follow: Bool = false) throws {
        var options: Int32 = 0
        if !follow {
            options = options | XATTR_NOFOLLOW
        }
        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = data.withUnsafeBytes {
                setxattr(fileSystemPath, name, $0.baseAddress, data.count, 0, options)
            }
            guard result >= 0 else { throw URL.posixError(errno) }
        }
    }

    /// Helper function to create an NSError from a Unix errno.
    private static func posixError(_ err: Int32) -> NSError {
        NSError(domain: NSPOSIXErrorDomain,
                code: Int(err),
                userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
    }
}
