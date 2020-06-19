//
//  View.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 10.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

extension View {
    func endEditing(_ force: Bool) {
        let keyWindow = UIApplication.shared.connectedScenes
                           .filter { $0.activationState == .foregroundActive }
                           .compactMap { $0 as? UIWindowScene }
                           .first?.windows
                           .first { $0.isKeyWindow }
        keyWindow?.endEditing(force)
    }
    
    func resignKeyboardOnDragGesture() -> some View {
        return modifier(ResignKeyboardOnDragGesture())
    }
}
