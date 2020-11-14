//
//  SortDescriptors.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 17.12.18.
//
// Source from: http://chris.eidhof.nl/post/sort-descriptors-in-swift/
//

import Foundation

/// A type that can be sorted by a NSSortDescriptor.
public protocol CustomComparable {

    /// Compare this object with another object of this type, using a NSSortDescriptor.
    ///
    /// - Parameters:
    ///   - other: Object that should be used for comparison.
    ///   - sortDescriptor: NSSortDescriptor that should be used by comparison.
    /// - Returns: Comparison result.
    func isBefore(_ other: Self, _ sortDescriptor: NSSortDescriptor) throws -> Bool
}

/// Sort items by some sort descriptors.
///
/// - Parameters:
///   - items: Items that should be sorted.
///   - sortDescriptors: Descriptors that specify the sorting.
/// - Returns: Sorted items.
public func sort<Type: CustomComparable>(_ items: [Type], by sortDescriptors: [NSSortDescriptor]) throws -> [Type] {
    return try items.sorted { (lhs, rhs) -> Bool in
        for sortDescriptor in sortDescriptors {
            if try lhs.isBefore(rhs, sortDescriptor) { return true }
            if try rhs.isBefore(lhs, sortDescriptor) { return false }
        }
        return false
    }
}

/// Error which might be thrown in the SortDescriptor.
///
/// - invalidKey: Error that will be thrown, if an invalid key was found in the sort descriptor.
public enum SortDescriptorError: Error {
    case invalidKey
}
