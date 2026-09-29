//
//  ScanButtonReleaseTests.swift
//  ArchiverLib
//

import CoreGraphics
import Testing

@testable import ArchiverFeatures

@Suite("Releasing the held scan button")
struct ScanButtonReleaseTests {

    @Test("Releasing without sliding only scans")
    func releaseInPlaceScans() {
        #expect(ScanButtonRelease(translation: .zero) == .scan)
        #expect(ScanButtonRelease(translation: CGSize(width: 8, height: -10)) == .scan)
    }

    @Test("Releasing on the share bubble scans and shares")
    func releaseOnShareBubbleShares() {
        let target = ScanButtonRelease.shareTargetOffset
        #expect(ScanButtonRelease(translation: target) == .scanAndShare)
        #expect(ScanButtonRelease(translation: CGSize(width: target.width + 20, height: target.height + 20)) == .scanAndShare)
    }

    @Test("Releasing anywhere else cancels")
    func releaseElsewhereCancels() {
        #expect(ScanButtonRelease(translation: CGSize(width: -120, height: 0)) == .cancel)
        #expect(ScanButtonRelease(translation: CGSize(width: 0, height: -200)) == .cancel)
    }
}
