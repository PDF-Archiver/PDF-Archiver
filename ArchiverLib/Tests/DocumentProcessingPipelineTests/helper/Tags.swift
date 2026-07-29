//
//  Tags.swift
//  ArchiverLib
//

import Testing

extension Tag {
    /// Tests that run real Vision text recognition.
    ///
    /// They rasterize a full page at 3x and run one `VNRecognizeTextRequest`
    /// per detected text rectangle - a few seconds each on real hardware, but
    /// unbounded on the GitHub Actions VM, which has no GPU/Neural Engine
    /// access ("IOServiceMatching failed for: AppleM2ScalerParavirtDriver").
    /// Because `PDFOCREngine.recognizeText(in:)` blocks its thread, several of
    /// them in parallel also starve the cooperative pool and wedge the whole
    /// test run. The `ArchiverLib-CI` test plan therefore excludes this tag;
    /// the default `ArchiverLib` plan runs them locally.
    @Tag static var ocr: Self
}
