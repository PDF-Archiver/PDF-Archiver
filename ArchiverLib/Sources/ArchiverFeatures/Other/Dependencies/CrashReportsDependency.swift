//
//  CrashReportsDependency.swift
//  ArchiverLib
//

import ArchiverModels
import ComposableArchitecture
import Foundation
import Logging
#if canImport(MetricKit)
import MetricKit
#endif

/// A crash report MetricKit delivered, kept on disk until the user sends or dismisses it.
struct StoredCrashReport: Equatable, Sendable {
    let filename: String
    let data: Data
}

@DependencyClient
struct CrashReportsDependency {
    /// The crash reports stored by earlier sessions.
    var stored: @Sendable () -> [StoredCrashReport] = { [] }
    var discard: @Sendable (_ reports: [StoredCrashReport]) -> Void
    /// Stores every crash report MetricKit delivers and yields it once it is on disk.
    var storeIncoming: @Sendable () -> AsyncStream<StoredCrashReport> = { .finished }
}

extension CrashReportsDependency: TestDependencyKey {
    static let previewValue = Self(
        stored: { [] },
        discard: { _ in },
        storeIncoming: { .finished }
    )

    static let testValue = Self()
}

extension CrashReportsDependency: DependencyKey {
    static let liveValue = Self(
        stored: {
            let fileManager = FileManager.default
            let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            return urls
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .compactMap { url in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return StoredCrashReport(filename: url.lastPathComponent, data: data)
                }
        },
        discard: { reports in
            for report in reports {
                do {
                    try FileManager.default.removeItem(at: directory.appending(path: report.filename))
                } catch {
                    Logger.app.error("Failed to discard crash report", metadata: [
                        "error": "\(LogRedact.describe(error))"
                    ])
                }
            }
        },
        storeIncoming: {
            #if canImport(MetricKit)
            guard #available(iOS 27, macOS 27, *) else { return .finished }
            return AsyncStream { continuation in
                let task = Task {
                    for await report in MetricManager().diagnosticReports {
                        guard case .crash = report.result, let stored = store(report) else { continue }
                        continuation.yield(stored)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
            #else
            return .finished
            #endif
        }
    )

    private static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "CrashReports", directoryHint: .isDirectory)
    }

    #if canImport(MetricKit)
    @available(iOS 27, macOS 27, *)
    private static func store(_ report: DiagnosticReport) -> StoredCrashReport? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // A UUID suffix: two crashes in the same second must not overwrite each other.
            let timestamp = report.timeRange.end.formatted(.iso8601.timeSeparator(.omitted))
            let filename = "Crash-Report-\(timestamp)-\(UUID().uuidString.prefix(8)).json"
            try data.write(to: directory.appending(path: filename), options: .atomic)
            Logger.app.notice("Stored a crash report")
            return StoredCrashReport(filename: filename, data: data)
        } catch {
            Logger.app.error("Failed to store crash report", metadata: [
                "error": "\(LogRedact.describe(error))"
            ])
            return nil
        }
    }
    #endif
}

extension DependencyValues {
    var crashReports: CrashReportsDependency {
        get { self[CrashReportsDependency.self] }
        set { self[CrashReportsDependency.self] = newValue }
    }
}
