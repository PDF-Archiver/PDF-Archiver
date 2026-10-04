//
//  FileManager+UniqueFileURL.swift
//  ArchiverLib
//

import Foundation

extension FileManager {
    /// `filename` inside `folder`, or the same name with a short random suffix
    /// before the extension when a file of that name already exists there.
    func uniqueFileURL(for filename: String, in folder: URL) -> URL {
        let url = folder.appendingPathComponent(filename, isDirectory: false)
        guard fileExists(atPath: url.path) else { return url }

        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let suffix = UUID().uuidString.prefix(8).lowercased()
        return folder.appendingPathComponent("\(base)-\(suffix)" + (ext.isEmpty ? "" : ".\(ext)"), isDirectory: false)
    }
}
