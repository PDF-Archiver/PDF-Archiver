//
//  MoreTabView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import LogModel
import MessageUI
import SwiftUI

struct MoreTabView: View {

    @ObservedObject var viewModel: MoreTabViewModel
    private static let appVersion = AppEnvironment.getFullVersion()

    var body: some View {
        HStack {
            Spacer()
            NavigationView {
                List {
                    preferences
                    moreInformation
                }.listStyle(GroupedListStyle())
                    .disabled(!MFMailComposeViewController.canSendMail())
                    .sheet(isPresented: $viewModel.isShowingMailView) {
                        SupportMailView(subject: MoreTabViewModel.mailSubject,
                                        recipients: MoreTabViewModel.mailRecipients,
                                        result: self.$viewModel.result)
                }
                .navigationBarTitle("Preferences & More")
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .frame(maxWidth: 700)
            Spacer()
        }
    }

    private var preferences: some View {
        Section(header: Text("🛠 Preferences")) {
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
        Section(header: Text("⁉️ More Information"), footer: Text("Version \(MoreTabView.appVersion)")) {
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
