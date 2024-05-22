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
    let messagePrefix: String
    let errorHandler: (Error) -> Void
    @Environment(\.presentationMode) private var presentation

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding private var presentation: PresentationMode
        private let errorHandler: (Error) -> Void

        init(presentation: Binding<PresentationMode>, errorHandler: @escaping (Error) -> Void) {
            _presentation = presentation
            self.errorHandler = errorHandler
        }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            defer {
                $presentation.wrappedValue.dismiss()
            }
            if let error = error {
                errorHandler(error)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation,
                           errorHandler: errorHandler)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<SupportMailView>) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()

        // set basic mail settings
        mail.mailComposeDelegate = context.coordinator
        mail.setToRecipients(recipients)
        mail.setSubject(subject)
        mail.setMessageBody("\(messagePrefix)\n\n\nDiagnostics Report:", isHTML: false)

        // add a diagnostics report
        var reporters = DiagnosticsReporter.DefaultReporter.allReporters
        reporters.insert(CustomDiagnosticsReporter(), at: 1)
        let report = DiagnosticsReporter.create(using: reporters)
        mail.addDiagnosticReport(report)

        return mail
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController,
                                context: UIViewControllerRepresentableContext<SupportMailView>) {

    }
}
#endif
