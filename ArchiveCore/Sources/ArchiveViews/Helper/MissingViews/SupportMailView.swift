//
//  SupportMailView.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 13.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

#if canImport(MessageUI)
import Diagnostics
import MessageUI
import SwiftUI

struct SupportMailView: UIViewControllerRepresentable {

    let subject: String
    let recipients: [String]

    @Environment(\.presentationMode) var presentation
    @Binding var result: Result<MFMailComposeResult, Error>?

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {

        @Binding var presentation: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(presentation: Binding<PresentationMode>, result: Binding<Result<MFMailComposeResult, Error>?>) {
            _presentation = presentation
            _result = result
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            defer {
                $presentation.wrappedValue.dismiss()
            }
            if let error = error {
                self.result = .failure(error)
            } else {
                self.result = .success(result)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation,
                           result: $result)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<SupportMailView>) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()

        // set basic mail settings
        mail.mailComposeDelegate = context.coordinator
        mail.setToRecipients(recipients)
        mail.setSubject(subject)
        mail.setMessageBody("\n\n\nDiagnostics Report:", isHTML: false)

        // add a diagnostics report
        var reporters = DiagnosticsReporter.DefaultReporter.allReporters
        reporters.insert(CustomDiagnosticsReporter.self, at: 1)
        let report = DiagnosticsReporter.create(using: reporters)
        mail.addDiagnosticReport(report)

        return mail
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: UIViewControllerRepresentableContext<SupportMailView>) {

    }
}
#endif
