//
//  AboutMeView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct AboutMeView: View {

    private static let profilePictureWidth: CGFloat = 120.0
//    private static let aboutText = """
//Hello 🤗
//
//I'm Julian - the developer of PDF Archiver. I started this project in 2017 with the macOS App and put a lot of heart and soul into it. 🙄
//Friends of mine and I 👨🏻‍💻 have been looking for a way to digitally sort documents so that they can be easily retrieved. 🕵🏻 We didn't want to use a cloud service where our documents would disappear into any database. We wanted a concept where as much information as possible could be stored in the file name. 💾 This is how we defined the following naming scheme:
//
//2019-07-04--blue-pullover__clothing_invoice.pdf
//
//It contains a date, a description and tags. Everything together forms the file name, which can be easily searched on various operating systems.
//To make this sorting as easy as possible I brought PDF Archiver to the iPhone. Here documents can be scanned and then automatically analyzed. 🤯 The intelligent text recognition takes place exclusively on your device, so no private information leaves your device! 🔒
//
//PDF Archiver is intended as a tool for your personal document workflow. So if you saved some time archiving your documents, or if there was a moment when you were happy to have all your documents on your iPhone, feel free to write a short comment on the App Store. 🖋
//
//Made with 💚 and 🙇🏻‍♂️ in Oldenburg, Germany.
//"""

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 32.0) {
                headline
                profilePicture
                text
            }
        }
    }

    private var headline: some View {
        HStack {
            Image("Logo")
                .resizable()
                .frame(width: 50.0, height: 50.0, alignment: .center)
            VStack(alignment: .leading, spacing: 4.0) {
                Text("PDF Archiver")
                    .font(.system(size: 24.0, weight: .heavy, design: .default))
                    .foregroundColor(Color(.paDarkGray))
                Text("Scan it. Tag it. Find it.")
                    .font(.system(size: 17.0, weight: .regular, design: .default))
                    .foregroundColor(Color(.paLightGray))
            }
        }
    }

    private var profilePicture: some View {
        Image("me-photo")
            .resizable()
            .cornerRadius(AboutMeView.profilePictureWidth / 4)
            .frame(width: AboutMeView.profilePictureWidth, height: AboutMeView.profilePictureWidth, alignment: .center)
    }

    private var text: some View {
        Text("AboutMeViewText")
            .padding(EdgeInsets(top: 0.0, leading: 16.0, bottom: 16.0, trailing: 16.0))
    }
}

struct AboutMeView_Previews: PreviewProvider {
    static var previews: some View {
        AboutMeView()
    }
}
