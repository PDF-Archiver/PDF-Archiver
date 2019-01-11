//
//  TagHandling.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 21.01.18.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import SystemConfiguration

// MARK: check network connection
func connectedToNetwork() -> Bool {
    // source: https://stackoverflow.com/a/25623647
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    zeroAddress.sin_family = sa_family_t(AF_INET)

    guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            SCNetworkReachabilityCreateWithAddress(nil, $0)
        }
    }) else {
        return false
    }

    var flags: SCNetworkReachabilityFlags = []
    if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
        return false
    }

    let isReachable = flags.contains(.reachable)
    let needsConnection = flags.contains(.connectionRequired)

    return (isReachable && !needsConnection)
}

func getNumberOfDonations() -> String {
    var contents = "0"
    do {
        contents = try String(contentsOf: Constants.donationCount)
    } catch {
        // contents could not be loaded
    }
    return contents.replacingOccurrences(of: "\n", with: "", options: .regularExpression)
}
