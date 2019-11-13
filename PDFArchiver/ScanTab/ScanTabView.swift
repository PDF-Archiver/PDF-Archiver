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
    @ObservedObject var viewModel: ScanTabViewModel

    var body: some View {
        VStack {
            Spacer()
            staticInfo
            Spacer()
            VStack(alignment: .leading) {
                if viewModel.progressValue > 0.0 {
                    Text(viewModel.progressLabel)
                    ProgressView(value: viewModel.progressValue)
                } else {
                    Text(viewModel.progressLabel)
                        .hidden()
                    ProgressView(value: viewModel.progressValue)
                        .hidden()
                }
                scanButton
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: 32.0, leading: 16.0, bottom: 32.0, trailing: 16.0))
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
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
        .padding(16.0)
        .foregroundColor(Color(.paDarkGray))
    }

    var scanButton: some View {
        Button(action: {
            self.viewModel.startScanning()
        }, label: {
            Text("Scan")
        }).buttonStyle(FilledButtonStyle())
    }
}

struct ScanTabView_Previews: PreviewProvider {
    static var previews: some View {
        ScanTabView(viewModel: ScanTabViewModel())
            .frame(maxWidth: .infinity)
            .padding()
    }
}
