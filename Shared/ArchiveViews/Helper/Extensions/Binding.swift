//
//  Binding.swift
//  
//
//  Created by Julian Kahnert on 06.01.21.
//

import SwiftUI

extension Binding where Value == Bool {
    func negate() -> Binding<Bool> {
        Binding(get: { !wrappedValue },
                set: { wrappedValue = !$0 })
    }
}
