//
//  AlertDataModel.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation
import SwiftUI

public struct AlertDataModel: Identifiable {
    public struct ButtonData {
        let role: ButtonRole?
        let action: (() -> Void)?
        let label: LocalizedStringResource
    }

    public let id = UUID()
    public let title: LocalizedStringResource
    public let message: LocalizedStringResource
    public let primaryButton: ButtonData
}
