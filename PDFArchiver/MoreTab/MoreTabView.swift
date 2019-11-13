//
//  MoreTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import  MessageUI
import SwiftUI

struct MoreTabView: View {

    @ObservedObject var viewModel: MoreTabViewModel

    var body: some View {
        NavigationView {
            List {
                preferences
                moreInformation
            }.listStyle(GroupedListStyle())
            .alert(isPresented: $viewModel.isShowingResetAlert) {
                // TODO: add localization
                Alert(title: Text("Reset App"),
                      message: Text("Please restart the app to complete the reset."),
                      dismissButton: .default(Text("OK")))
            }
            .disabled(!MFMailComposeViewController.canSendMail())
            .sheet(isPresented: $viewModel.isShowingMailView) {
                MailView(subject: MoreTabViewModel.mailSubject,
                         recipients: MoreTabViewModel.mailRecipients,
                         result: self.$viewModel.result)
            }
            .navigationBarTitle("Preferences & More")
        }.navigationViewStyle(StackNavigationViewStyle())
    }

    private var preferences: some View {
        Section(header: Text("⚒ Preferences")) {
            Picker(selection: $viewModel.selectedQualityIndex, label: Text("PDF Quality")) {
                ForEach(0..<viewModel.qualities.count, id: \.self) {
                    Text(self.viewModel.qualities[$0])
                }
            }
            DetailRowView(name: "Show Intro") {
                self.viewModel.showIntro()
            }
            DetailRowView(name: "Show Permissions") {
                self.viewModel.showPermissions()
            }
            DetailRowView(name: "Reset App Preferences") {
                self.viewModel.resetApp()
            }
            DetailRowView(name: "Manage Subscription") {
                self.viewModel.showManageSubscription()
            }
        }
    }

    private var moreInformation: some View {
        Section(header: Text("⁉️ More Information"), footer: Text("TODO App Version")) {
            NavigationLink(destination: AboutMeView()) {
                Text("About  👤")
            }
            DetailRowView(name: "PDF Archiver (macOS)  🖥") {
                self.viewModel.showMacOSApp()
            }
            DetailRowView(name: "Terms of Use & Privacy Policy") {
                self.viewModel.showPrivacyPolicy()
            }
            DetailRowView(name: "Imprint") {
                self.viewModel.showImprintCell()
            }
            DetailRowView(name: "Support  🚑") {
                self.viewModel.showSupport()
            }
        }
    }
}

struct MoreTabView_Previews: PreviewProvider {
    @State static var viewModel = MoreTabViewModel()
    static var previews: some View {
        MoreTabView(viewModel: viewModel)
    }
}
