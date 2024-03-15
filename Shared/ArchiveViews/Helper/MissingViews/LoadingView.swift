//
//  LoadingView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 25.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import SwiftUIX

struct LoadingView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 32.0) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(2, anchor: .center)
            Text("Loading documents ...")
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
