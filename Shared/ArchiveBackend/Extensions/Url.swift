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

    public func getFileTags() -> [String] {
        do {
            #if os(macOS)
            // prefer native tagNames https://stackoverflow.com/a/47340666
            return try resourceValues(forKeys: [.tagNamesKey]).tagNames ?? []
            #else
            return try getiOSFileTags()
            #endif
        } catch {
            log.error("Error while getting tag names", metadata: ["error": "\(error)"])
            return []
        }
    }
    
    public func uniqueId() -> Int? {
        do {
            return try resourceValues(forKeys: [.documentIdentifierKey]).documentIdentifier
        } catch {
            log.error("Error while getting unique document identifier", metadata: ["error": "\(error)"])
            return nil
        }
    }
    
    public func filename() -> String? {
         do {
             return try resourceValues(forKeys: [.localizedNameKey]).localizedName
         } catch {
             log.error("Error while getting filename", metadata: ["error": "\(error)"])
             return nil
         }
    }
    
    public func fileCreationDate() -> Date? {
        do {
            return try resourceValues(forKeys: [.creationDateKey]).creationDate
        } catch {
            log.error("Error while getting filename", metadata: ["error": "\(error)"])
            return nil
        }
    }

    public func setFileTags(_ tags: [String]) {
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

    private func getiOSFileTags() throws -> [String] {
        var tags = [String]()
        let data = try self.getExtendedAttribute(forName: URL.itemUserTagsName)
        if let tagPlist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String] {
            log.debug("using PropertyListSerialization")
            tags = tagPlist
        } else if let newTags = try NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: NSString.self, from: data) as? [String] {
            log.debug("using NSKeyedUnarchiver")
            tags = newTags
        }

        // some lokal tags are saved with a "\n0" or "\n1" suffix, e.g. "ikea\n1"
        let fixedTags = tags
            .compactMap { $0.split(separator: "\n").first}
            .map { String($0)}

        // additional logs for the testflight/debug environment to get the "duplicated tags" bug debugged/fixed
        if AppEnvironment.get() != .production,
           fixedTags.contains(where: {$0.last == "1"}) {
            log.error("Duplicated tags bug occurred", metadata: ["tags": "\(tags.joined(separator: "&"))", "fixedTags": "\(fixedTags.joined(separator: "&"))", "dataBase64": "\(data.base64EncodedString())"])
        }

        return fixedTags
    }

    private func setiOSFileTags(_ fileTags: [String]) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: fileTags, requiringSecureCoding: false)
        try setExtendedAttribute(data: data, forName: URL.itemUserTagsName)
    }

    /// Get extended attribute.
    private func getExtendedAttribute(forName name: String, follow: Bool = false) throws -> Data {
        var options: Int32 = 0
        if !follow {
            options = options | XATTR_NOFOLLOW
        }
        let data = try withUnsafeFileSystemRepresentation { fileSystemPath -> Data in
            // Determine attribute size:
            let length = getxattr(fileSystemPath, name, nil, 0, 0, options)
            guard length >= 0 else { throw URL.posixError(errno) }

            // Create buffer with required size:
            var data = Data(count: length)

            // Retrieve attribute:
            let result = data.withUnsafeMutableBytes { [count = data.count] in
                getxattr(fileSystemPath, name, $0.baseAddress, count, 0, 0)
            }
            guard result >= 0 else { throw URL.posixError(errno) }
            return data
        }
        return data
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
