//
//  TagIndex.swift
//  
//
//  Created by Julian Kahnert on 10.02.20.
//

import Foundation

public struct TagIndex<IndexElement: Hashable> {
    private var content = [IndexElement: Set<IndexElement>]()

    mutating func add(_ elements: Set<IndexElement>, for key: IndexElement) {
        content[key, default: Set()].formUnion(elements)
    }

    mutating func add(_ elements: Set<IndexElement>) {
        for element in elements {
            let otherElements = elements.subtracting(Set([element]))
            content[element, default: Set()].formUnion(otherElements)
        }
    }

    public func getElements(for key: IndexElement) -> Set<IndexElement> {
        content[key] ?? Set()
    }

    public subscript(key: IndexElement) -> Set<IndexElement> {
        getElements(for: key)
    }
}
