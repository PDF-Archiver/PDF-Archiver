//
//  TagCount.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 05.10.25.
//

import Foundation

nonisolated public struct TagCount: Equatable, Sendable {
    public let tag: String
    public let count: Int

    public init(tag: String, count: Int) {
        self.tag = tag
        self.count = count
    }
}
