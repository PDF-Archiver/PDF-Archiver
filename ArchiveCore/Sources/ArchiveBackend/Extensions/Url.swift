//
//  Url.swift
//  
//
//  Created by Julian Kahnert on 29.11.19.
//

import Foundation
#if os(OSX)
import Quartz.PDFKit
#else
import PDFKit
#endif

// Source Code from: https://github.com/amyspark/xattr
extension URL {

    private static let itemUserTagsName = "com.apple.metadata:_kMDItemUserTags"

    /// Finder file tags
    public var fileTags: [String] {
        get {
            var tags = [String]()

            if let documentAttributes = PDFDocument(url: self)?.documentAttributes,
                let keywords = documentAttributes[PDFDocumentAttribute.keywordsAttribute] as? [String] {
                tags.append(contentsOf: keywords)
            }

            // prefer native tagNames and 
            #if os(OSX)
            // https://stackoverflow.com/a/47340666
            if let resourceValues = try? self.resourceValues(forKeys: [.tagNamesKey]),
                let tagNames = resourceValues.tagNames {
                tags.append(contentsOf: tagNames)
            }
            #else
            tags.append(contentsOf: getFileTags())
            #endif

            return tags
        }
        set {
            let tags = newValue

            // write pdf document attributes
            if let document = PDFDocument(url: self),
                var docAttrib = document.documentAttributes {

                // get current document tags
                let currentAttrib = (docAttrib[PDFDocumentAttribute.keywordsAttribute] as? [String]) ?? []

                // write new document tags if needed
                if currentAttrib != tags {
                    docAttrib[PDFDocumentAttribute.keywordsAttribute] = newValue
                    document.documentAttributes = docAttrib
                    document.write(to: self)
                }
            }

            #if os(OSX)
            // https://stackoverflow.com/a/47340666
            try? (self as NSURL).setResourceValue(tags, forKey: URLResourceKey.tagNamesKey)
            #else
            setFileTags(tags)
            #endif
        }
    }

    private func getFileTags() -> [String] {
        var tags = [String]()
        if let data = try? self.getExtendedAttribute(forName: URL.itemUserTagsName) {
            if let tagPlist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String] {

                tags = tagPlist.map { tag -> String in
                    var newTag = tag
                    if newTag.suffix(2) == "\n0" {
                        newTag.removeLast(2)
                    }
                    return newTag
                }

            } else if let newTags = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String] {

                tags = newTags

            }
        }
        return tags
    }

    @available(OSX 10.13, *)
    private func setFileTags(_ fileTags: [String]) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: fileTags, requiringSecureCoding: false) else { return }
        try? setExtendedAttribute(data: data, forName: URL.itemUserTagsName)
    }

    /// Get extended attribute.
    private func getExtendedAttribute(forName name: String, follow: Bool = false) throws -> Data {
        var options: Int32 = 0
        if !follow {
            options = options | XATTR_NOFOLLOW
        }
        let data = try self.withUnsafeFileSystemRepresentation { fileSystemPath -> Data in
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
    func setExtendedAttribute(data: Data, forName name: String, follow: Bool = false) throws {
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
        return NSError(domain: NSPOSIXErrorDomain,
                       code: Int(err),
                       userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
    }
}
