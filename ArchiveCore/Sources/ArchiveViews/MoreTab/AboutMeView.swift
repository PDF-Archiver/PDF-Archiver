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
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.paDarkGray)
                Text("Scan it. Tag it. Find it.")
                    .font(.title)
                    .foregroundColor(.paLightGray)
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

#if DEBUG
struct AboutMeView_Previews: PreviewProvider {
    static var previews: some View {
        AboutMeView()
            .makeForPreviewProvider()
    }
}
#endif
