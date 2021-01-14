//
//  Binding.swift
//  
//
//  Created by Julian Kahnert on 06.01.21.
//

import SwiftUI

extension Binding where Value == [String] {
    func insertAndSort(_ item: String) {
        var uniqueItems = Set(wrappedValue)
        uniqueItems.insert(item)
        wrappedValue = uniqueItems.sorted()
    }
}
