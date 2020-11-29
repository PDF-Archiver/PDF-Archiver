//
//  Atomic.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 05.01.19.
//
// Source from: https://www.objc.io/blog/2018/12/18/atomic-variables/

import Foundation

public final class Atomic<A> {
    private let queue = DispatchQueue(label: UUID().uuidString)
    private var _value: A
    public init(_ value: A) {
        self._value = value
    }

    public var value: A {
        return queue.sync { self._value }
    }

    public func mutate(_ transform: (inout A) -> Void) {
        queue.sync {
            transform(&self._value)
        }
    }
}
