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
    let id = UUID()
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
}
