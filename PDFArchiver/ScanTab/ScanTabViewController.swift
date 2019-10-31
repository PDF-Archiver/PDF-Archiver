//
//  ScanTabViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 31.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI
import UIKit

struct ScanTabView: View {

    var body: some View {
        VStack {
            staticInfo
            Spacer()
            Button(action: {
                print("TAP")
            }, label: {
                Text("Test")
            })
        }
    }

    var staticInfo: some View {
        VStack(alignment: .leading) {
            Image("Logo")
                .resizable()
                .frame(width: 100.0, height: 100.0, alignment: .leading)
                .padding()
            Text("Welcome to")
                .font(.system(size: 24.0, weight: .heavy))
            Text("PDF Archiver")
                .foregroundColor(Color(.paDarkRed))
                .font(.system(size: 24.0, weight: .heavy))
            Text("Scan your documents, tag them and find them sorted in your iCloud Drive.")
                .font(.system(size: 15.0))
                .lineLimit(nil)
        }
        .foregroundColor(Color(.paDarkGray))
    }
}

struct ScanTabView_Previews: PreviewProvider {
    static var previews: some View {
        ScanTabView()
            .frame(maxWidth: .infinity)
            .padding()
    }
}
