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
        ZStack {
            Color.systemGray
                .opacity(0.8)
            
            VStack(alignment: .leading, spacing: 32.0) {
                title
                text
                HStack {
                    Spacer()
                    buttons
                    Spacer()
                }
                subscriptionButtons
                text
                Spacer()
                otherButtons
            }.padding(EdgeInsets(top: 32.0, leading: 16.0, bottom: 32.0, trailing: 16.0))
            .background(Color(.systemBackground))
            .maxWidth(600)
            .cornerRadius(25)
        }.edgesIgnoringSafeArea(.all)
    }

    var title: some View {
        HStack {
            Image("Logo")
                .resizable()
                .frame(width: 75.0, height: 75.0, alignment: .center)
            Spacer()
                .frame(width: 24, alignment: .center)
            Text("Subscription")
                .font(.largeTitle)
                .foregroundColor(Color(.paDarkGray))
            Spacer()
        }.padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    var text: some View {
        Text("• Try the app for free! You can try the app in a free trial period of 1 month by choosing a subscription. You can try the app without any costs in this period.\n• Your Apple account will be charged for the next subscriptioon period within the final 24 hours of the current period.\n• The subscription will renew automatically if you do not deactivate the renewal in the account setting in iTunes or the App Store at least 24 hours before the end of the subscription period.")
            .font(.caption)
            .foregroundColor(Color(.paLightGray))
    }

    var subscriptionButtons: some View {
        HStack(spacing: 16.0) {
            Button(action: {
                self.viewModel.tapped(button: .level1)
            }, label: {
                Text(viewModel.level1Name)
            })
            .buttonStyle(FilledButtonStyle())
            .aspectRatio(1, contentMode: .fit)
            Button(action: {
                self.viewModel.tapped(button: .level2)
            }, label: {
                Text(viewModel.level2Name)
            })
            .buttonStyle(FilledButtonStyle())
            .aspectRatio(1, contentMode: .fit)
        }
    }
    
    var otherButtons: some View {
        HStack(spacing: 16.0) {
            Button(action: {
                self.viewModel.tapped(button: .restore)
            }, label: {
                Text("Restore")
            })
            .buttonStyle(FilledButtonStyle(foregroundColor: Color(.paDarkGray), backgroundColor: Color(.paWhite)))

            Button(action: {
                self.viewModel.tapped(button: .cancel)
            }, label: {
                Text("Cancel")
            })
            .buttonStyle(FilledButtonStyle(foregroundColor: Color(.paDarkRed), backgroundColor: Color(.paWhite)))
        }
    }
}

struct IAPView_Previews: PreviewProvider {
    @State static var viewModel = IAPViewModel()
    static var previews: some View {
        IAPView(viewModel: viewModel)
    }
}
