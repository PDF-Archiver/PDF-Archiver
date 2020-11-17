//
//  SwiftUIView.swift
//  
//
//  Created by Julian Kahnert on 14.11.20.
//

import SwiftUI

#if os(macOS)
struct SettingsView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .previewDevice("Mac")
    }
}
#endif
