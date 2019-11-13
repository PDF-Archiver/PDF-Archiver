//
//  IAPView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import SwiftUI

struct IAPView: View {

    @ObservedObject var viewModel: IAPViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 32.0) {
            title
            text
            buttons
        }.padding(EdgeInsets(top: 32.0, leading: 16.0, bottom: 32.0, trailing: 16.0))
    }

    var title: some View {
        Text("Subscription")
            .font(.largeTitle)
            .foregroundColor(Color(.paDarkGray))
    }

    var text: some View {
        Text("• Try the app for free! You can try the app in a free trial period of 1 month by choosing a subscription. You can try the app without any costs in this period.\n• Your Apple account will be charged for the next subscriptioon period within the final 24 hours of the current period.\n• The subscription will renew automatically if you do not deactivate the renewal in the account setting in iTunes or the App Store at least 24 hours before the end of the subscription period.")
            .font(.body)
            .foregroundColor(Color(.paLightGray))
    }

    var buttons: some View {
        VStack(alignment: .center, spacing: 16.0) {
            Button(action: {
                self.viewModel.tapped(button: .level1)
            }, label: {
                Text(viewModel.level1Name)
            })
            Button(action: {
                self.viewModel.tapped(button: .level2)
            }, label: {
                Text(viewModel.level2Name)
            })
            Button(action: {
                self.viewModel.tapped(button: .restore)
            }, label: {
                Text("Restore")
            })
            Spacer()
                .frame(height: 1)
            Button(action: {
                self.viewModel.tapped(button: .cancel)
            }, label: {
                Text("Cancel")
                    .foregroundColor(Color(.paDarkRed))
            })
        }.buttonStyle(FilledButtonStyle())
    }
}

struct IAPView_Previews: PreviewProvider {
    @State static var viewModel = IAPViewModel()
    static var previews: some View {
        IAPView(viewModel: viewModel)
    }
}
