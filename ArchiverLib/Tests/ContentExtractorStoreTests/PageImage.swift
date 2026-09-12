//
//  PageImage.swift
//  ContentExtractorStoreTests
//

// `canImport` for the macOS 26 SDK of CI, which has no Evaluations module at
// all; `@available` for this package's macOS 15 floor - on each declaration and
// never on the `@Suite`, which the macro rejects (swift-testing#608).
#if os(macOS) && canImport(Evaluations)

import Foundation

/// The first page of each sample, rendered ahead of the run.
///
/// Rendering inside the test bundle hangs: the host app is signed and reading
/// the iCloud archive needs a TCC grant it can never be asked for in a headless
/// run. `Evaluations/prerender-pages.swift` writes the PNGs from a plain
/// command-line context instead, where that permission already exists.
enum PageImage {

    static let environmentKey = "PDF_ARCHIVER_EVAL_PAGES"

    /// - Returns: The page rendered for this document, or nil when it was not
    ///   pre-rendered - in which case the sample simply runs on text alone.
    static func url(for filename: String) -> URL? {
        guard let directory = ProcessInfo.processInfo.environment[environmentKey], !directory.isEmpty else { return nil }

        let page = URL(filePath: directory).appending(path: filename).deletingPathExtension().appendingPathExtension("png")
        return FileManager.default.fileExists(atPath: page.path(percentEncoded: false)) ? page : nil
    }
}

#endif
