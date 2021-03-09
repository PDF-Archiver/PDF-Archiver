//
//  RandomAccessCollection.swift
//  
//
//  Created by Julian Kahnert on 28.02.21.
//

import Foundation

extension RandomAccessCollection {
    public func get(at index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
