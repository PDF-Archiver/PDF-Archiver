//
//  SettingsRow.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.09.26.
//

#if os(macOS)
import SwiftUI

/// Title left, control right, help underneath — the row shape every pane's `Section` uses.
struct SettingsRow<Control: View>: View {
    let title: LocalizedStringKey
    var help: LocalizedStringKey?
    @ViewBuilder var control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title, bundle: #bundle)
                Spacer(minLength: 20)
                control
            }
            if let help {
                Text(help, bundle: #bundle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    // Ideal height, which is what a grouped `Form` sizes a row by, would
                    // otherwise be short of the wrapped text — the last line ends in an ellipsis.
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
#endif
