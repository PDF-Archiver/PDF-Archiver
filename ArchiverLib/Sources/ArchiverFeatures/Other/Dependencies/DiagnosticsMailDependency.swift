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
    /// Returns `true` only when Mail got the mail with every attachment.
    var send: @Sendable (DiagnosticsMail) async -> Bool = { _ in false }
}

extension DiagnosticsMailDependency: TestDependencyKey {
    static let previewValue = Self(
        createReport: { DiagnosticsReport(filename: "Diagnostics-Report.html", data: Data()) },
        send: { _ in false }
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
            return await MainActor.run { MacMail.send(mail) }
            #else
            return false
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
    /// - Attaches the files via the Mail compose service; `true` once every file went along.
    /// - Otherwise opens a `mailto:` link without attachments and reveals the files in Finder.
    static func send(_ mail: DiagnosticsMail) -> Bool {
        let urls = mail.attachments.compactMap(writeToTemporaryFile)
        guard !urls.isEmpty else {
            openMailtoFallback()
            return false
        }

        let service = NSSharingService(named: .composeEmail)
        service?.recipients = [Constants.mailRecipient]
        service?.subject = Constants.mailSubject
        guard let service, service.canPerform(withItems: urls) else {
            openMailtoFallback()
            NSWorkspace.shared.activateFileViewerSelecting(urls)
            return false
        }
        service.perform(withItems: urls)
        return urls.count == mail.attachments.count
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
