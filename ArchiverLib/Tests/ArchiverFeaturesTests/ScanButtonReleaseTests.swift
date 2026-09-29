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
        #expect(ScanButtonRelease(translation: .zero, isOverShareTarget: false) == .scan)
        #expect(ScanButtonRelease(translation: CGSize(width: 8, height: -10), isOverShareTarget: false) == .scan)
    }

    @Test("Releasing on the share bubble scans and shares")
    func releaseOnShareBubbleShares() {
        #expect(ScanButtonRelease(translation: ScanButtonRelease.shareTargetOffset, isOverShareTarget: true) == .scanAndShare)
    }

    @Test("Releasing anywhere else cancels")
    func releaseElsewhereCancels() {
        #expect(ScanButtonRelease(translation: CGSize(width: -120, height: 0), isOverShareTarget: false) == .cancel)
        #expect(ScanButtonRelease(translation: CGSize(width: 0, height: -200), isOverShareTarget: false) == .cancel)
    }

    @Test("A finger on the bubble's edge neither snaps on nor off")
    func edgeOfShareBubbleKeepsTheCurrentSnap() {
        let target = ScanButtonRelease.shareTargetOffset
        let onTheEdge = CGSize(width: target.width + 45, height: target.height)

        #expect(ScanButtonRelease.isOverShareTarget(onTheEdge, wasOverShareTarget: false) == false)
        #expect(ScanButtonRelease.isOverShareTarget(onTheEdge, wasOverShareTarget: true) == true)
    }

    @Test("Sliding onto the bubble snaps, sliding far away releases it")
    func shareBubbleSnapsOnAndOff() {
        let target = ScanButtonRelease.shareTargetOffset
        let farAway = CGSize(width: target.width + 80, height: target.height)

        #expect(ScanButtonRelease.isOverShareTarget(target, wasOverShareTarget: false) == true)
        #expect(ScanButtonRelease.isOverShareTarget(farAway, wasOverShareTarget: true) == false)
    }
}
