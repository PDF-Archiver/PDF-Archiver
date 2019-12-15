//
//  PlacerholderView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 14.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct PlaceholderView: View {
    let name: LocalizedStringKey
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .frame(width: 100.0, height: 100.0, alignment: .leading)
                .padding()
            Text(name)
                .font(.system(size: 15.0))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400.0)
        }
    }
}

struct PlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        PlaceholderView(name: "No iCloud Drive documents found. Please scan and tag documents first.")
    }
}
