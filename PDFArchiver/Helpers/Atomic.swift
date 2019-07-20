//
//  Atomic.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 16.07.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

final class Atomic<A> {
    private let queue = DispatchQueue(label: "Atomic serial queue")
    private var _value: A
    init(_ value: A) {
        self._value = value
    }

    var value: A {
        get {
            return queue.sync { self._value }
        }
    }

    func mutate(_ transform: (inout A) -> ()) {
        queue.sync {
            transform(&self._value)
        }
    }
}
