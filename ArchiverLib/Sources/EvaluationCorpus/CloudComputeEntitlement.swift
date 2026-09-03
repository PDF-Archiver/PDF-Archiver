//
//  CloudComputeEntitlement.swift
//  ArchiverLib
//

// `SecTask` is macOS-only; Private Cloud Compute is only ever driven from there.
#if os(macOS)

import Foundation
import Security

/// Whether the running binary may talk to Private Cloud Compute.
///
/// Nothing reports the missing grant up front: `availability` answers
/// `.available` and `contextSize` even resolves, but the first request calls
/// `fatalError("Missing entitlement: ...")`, which no `catch` can intercept.
/// So every caller has to ask this before it sends anything.
public enum CloudComputeEntitlement {

    public static let name = "com.apple.developer.private-cloud-compute"

    public static var isGranted: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, name as CFString, nil) else { return false }

        return (value as? Bool) == true
    }
}

#endif
