//
//  AlertDataModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import SwiftUI

struct AlertDataModel: Identifiable {
    struct ButtonData {
        let role: ButtonRole?
        let action: (() -> Void)?
        let label: LocalizedStringKey
    }

    let id = UUID()
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryButton: ButtonData
}
