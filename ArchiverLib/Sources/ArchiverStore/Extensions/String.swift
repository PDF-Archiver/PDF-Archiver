//
//  String.swift
//
//
//  Created by Julian Kahnert on 25.10.19.
//

import Foundation

extension String {
    var isNumeric: Bool {
        CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: self))
    }
}
