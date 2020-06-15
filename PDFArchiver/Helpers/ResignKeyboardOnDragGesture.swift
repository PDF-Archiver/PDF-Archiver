//
//  ResignKeyboardOnDragGesture.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 15.06.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct ResignKeyboardOnDragGesture: ViewModifier {
    func body(content: Content) -> some View {
        content.gesture(
            DragGesture().onChanged { _ in
                content.endEditing(true)
            }
        )
    }
}
