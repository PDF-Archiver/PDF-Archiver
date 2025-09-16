//
//  TextState.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 15.09.25.
//

import ComposableArchitecture
import Foundation

public extension TextState {
    init(_ value: String.LocalizationValue, bundle: Bundle) {
        self.init(String(localized: value, bundle: bundle))
    }
}
