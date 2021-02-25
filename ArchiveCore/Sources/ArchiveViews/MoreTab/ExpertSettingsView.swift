//
//  SwiftUIView.swift
//  
//
//  Created by Julian Kahnert on 25.02.21.
//

import SwiftUI

struct ExpertSettingsView: View {
    @Binding var notSaveDocumentTagsAsPDFMetadata: Bool
    @Binding var documentTagsNotRequired: Bool
    @Binding var documentSpecificationNotRequired: Bool
    var showPermissions: (() -> Void)?
    var resetApp: () -> Void

    var body: some View {
        Form {
            Toggle("Save Tags in PDF Metadata", isOn: $notSaveDocumentTagsAsPDFMetadata.negate())
            Toggle("Require Document Tags", isOn: $documentTagsNotRequired.negate())
            Toggle("Require Document Specification", isOn: $documentSpecificationNotRequired.negate())
            if let showPermissions = showPermissions {
                DetailRowView(name: "Show Permissions", action: showPermissions)
            }
            DetailRowView(name: "Reset App Preferences", action: resetApp)
        }
    }
}

#if DEBUG
struct ExpertSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ExpertSettingsView(notSaveDocumentTagsAsPDFMetadata: .constant(true),
                           documentTagsNotRequired: .constant(false),
                           documentSpecificationNotRequired: .constant(false),
                           resetApp: {
                            print("Tapped reset")
                           })
    }
}
#endif
