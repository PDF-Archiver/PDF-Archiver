//
//  Tags.swift
//  ArchiverLib
//

import Testing

extension Tag {
    /// Tests that run real Vision text recognition.
    ///
    /// They rasterize a full page at 3x and run it through Vision - a few
    /// seconds each on real hardware, but unbounded on the GitHub Actions VM,
    /// which has no GPU/Neural Engine access ("IOServiceMatching failed for:
    /// AppleM2ScalerParavirtDriver"). The `ArchiverLib-CI` test plan therefore
    /// excludes this tag; the default `ArchiverLib` plan runs them locally.
    @Tag static var ocr: Self
}
