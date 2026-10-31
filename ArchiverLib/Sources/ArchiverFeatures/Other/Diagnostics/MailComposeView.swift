//
//  MailComposeView.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 09.10.25.
//

#if os(iOS)
import MessageUI
import SwiftUI

struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let attachments: [MailAttachment]
    /// Called with `true` when the mail was sent or saved as a draft.
    let onFinish: (_ sent: Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        for attachment in attachments {
            composer.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.filename)
        }
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (_ sent: Bool) -> Void

        init(onFinish: @escaping (_ sent: Bool) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish(result == .sent || result == .saved)
        }
    }
}
#endif
