//
//  View.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.10.25.
//

import SwiftUI

extension View {
    public func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}
