//
//  ICloudDownloadStatusTests.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 02.10.26.
//

import Foundation
import Testing

@testable import ArchiverStore

@Suite
struct ICloudDownloadStatusTests {
    @Test(arguments: [URLUbiquitousItemDownloadingStatus.current, .downloaded])
    func aFileOnThisDeviceCountsAsDownloaded(status: URLUbiquitousItemDownloadingStatus) {
        #expect(status.documentStatus(isDownloading: false, percentDownloaded: nil) == 1)
    }

    @Test
    func aRemoteFileCountsAsNotDownloaded() {
        #expect(URLUbiquitousItemDownloadingStatus.notDownloaded.documentStatus(isDownloading: false, percentDownloaded: 40) == 0)
    }

    @Test
    func aRunningDownloadReportsItsProgress() {
        #expect(URLUbiquitousItemDownloadingStatus.notDownloaded.documentStatus(isDownloading: true, percentDownloaded: 40) == 0.4)
    }

    @Test
    func anUnknownStatusIsSkipped() {
        #expect(URLUbiquitousItemDownloadingStatus(rawValue: "future").documentStatus(isDownloading: false, percentDownloaded: nil) == nil)
    }
}
