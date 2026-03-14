//
//  ScanControlWidget.swift
//  Widget
//
//  Created by Julian Kahnert on 14.03.26.
//

import SwiftUI
import WidgetKit

struct ScanControlWidget: ControlWidget {
    static let kind = "ScanControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenScanControlIntent()) {
                Label("Scan", systemImage: "doc.viewfinder")
            }
        }
        .displayName("Scan Document")
        .description("Quickly scan a document into your archive.")
    }
}
