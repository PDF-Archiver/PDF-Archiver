//
//  DiagnosticsMailDependency.swift
//  ArchiverLib
//

import ArchiverModels
import ComposableArchitecture
import Diagnostics
import Foundation
import Logging
import Shared
#if os(macOS)
import AppKit
#endif

@DependencyClient
struct DiagnosticsMailDependency {
    var createReport: @Sendable () async -> DiagnosticsReport = {
        DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data())
    }
    /// Hands the mail to Mail on macOS; iOS presents `MailComposeView` from the flow's state instead.
    var send: @Sendable (DiagnosticsMail) async -> Void
}

extension DiagnosticsMailDependency: TestDependencyKey {
    static let previewValue = Self(
        createReport: { DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data()) },
        send: { _ in }
    )

    static let testValue = Self()
}

extension DiagnosticsMailDependency: DependencyKey {
    static let liveValue = Self(
        createReport: {
            // Logged before the report reads the log, so a report from a long-running
            // session still carries the current state and not only the one from launch.
            await AppStateLog.log()
            return await DiagnosticsReporter.create(
                using: [DiagnosticsReporter.DefaultReporter.generalInfo.reporter,
                        DiagnosticsReporter.DefaultReporter.appSystemMetadata.reporter,
                        OSLogReporter(),
                        ArchiveLogFileReporter()],
                filters: [SensitivePathFilter.self]
            )
        },
        send: { mail in
            #if os(macOS)
            await MainActor.run { MacMail.send(mail) }
            #endif
        }
    )
}

extension DependencyValues {
    var diagnosticsMail: DiagnosticsMailDependency {
        get { self[DiagnosticsMailDependency.self] }
        set { self[DiagnosticsMailDependency.self] = newValue }
    }
}

#if os(macOS)
@MainActor
private enum MacMail {
    /// Attaches the files via the Mail compose service; falls back to a plain `mailto:` link
    /// (no attachments) when there is nothing to attach, no mail client is configured or no file
    /// could be written (revealing the written files in Finder in the no-client case).
    static func send(_ mail: DiagnosticsMail) {
        let urls = mail.attachments.compactMap(writeToTemporaryFile)
        guard !urls.isEmpty else {
            openMailtoFallback()
            return
        }

        let service = NSSharingService(named: .composeEmail)
        service?.recipients = [Constants.mailRecipient]
        service?.subject = Constants.mailSubject
        guard let service, service.canPerform(withItems: urls) else {
            openMailtoFallback()
            NSWorkspace.shared.activateFileViewerSelecting(urls)
            return
        }
        service.perform(withItems: urls)
    }

    private static func writeToTemporaryFile(_ attachment: MailAttachment) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.filename)
        do {
            try attachment.data.write(to: url)
            return url
        } catch {
            Logger.settings.errorAndAssert("Failed to write mail attachment", metadata: ["error": "\(LogRedact.describe(error))"])
            return nil
        }
    }

    private static func openMailtoFallback() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Constants.mailRecipient
        components.queryItems = [URLQueryItem(name: "subject", value: Constants.mailSubject)]
        guard let url = components.url else {
            Logger.settings.errorAndAssert("Failed to create mailto url")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
#endif
