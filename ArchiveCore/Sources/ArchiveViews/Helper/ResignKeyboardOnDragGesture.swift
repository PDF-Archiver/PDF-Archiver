//
//  ResignKeyboardOnDragGesture.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 15.06.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import SwiftUI
import SwiftUIX

struct ResignKeyboardOnDragGesture: ViewModifier {
    func body(content: Content) -> some View {
        content.gesture(
            DragGesture().onChanged { _ in
                #if !os(macOS)
                Keyboard.main.dismiss()
                #endif
            }
        )
    }
}
