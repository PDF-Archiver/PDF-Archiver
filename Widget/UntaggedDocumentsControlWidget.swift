//
//  UntaggedDocumentsControlWidget.swift
//  Widget
//
//  Created by Julian Kahnert on 14.03.26.
//

import Shared
import SwiftUI
import WidgetKit

struct UntaggedDocumentsControlWidget: ControlWidget {
    static let kind = "UntaggedDocumentsControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind,
                                   provider: UntaggedDocumentsControlProvider()) { value in
            ControlWidgetButton(action: OpenTagControlIntent()) {
                Label("\(value.count) Untagged", systemImage: "tray.full")
            }
        }
        .displayName("Untagged Documents")
        .description("See untagged document count and open inbox.")
    }
}

struct UntaggedDocumentsControlProvider: ControlValueProvider {
    struct Value {
        let count: Int
    }

    var previewValue: Value { Value(count: 3) }

    func currentValue() async throws -> Value {
        let count = await SharedDefaults.getUntaggedDocumentsCount()
        return Value(count: count)
    }
}
