import ArchiverModels
import ArchiverStore
import Combine
import ComposableArchitecture
import Foundation
import Logging
import Shared
import Synchronization
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Forwards every line of `debug` and above to ``ArchiveLogFile``.
struct ArchiveLogFileHandler: LogHandler {
    var logLevel: Logger.Level = .debug
    var metadata = Logger.Metadata()
    var metadataProvider: Logger.MetadataProvider?

    private let label: String
    private let file: ArchiveLogFile

    init(label: String, file: ArchiveLogFile = .shared) {
        self.label = label
        self.file = file
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        guard let sequenceNumber = file.nextSequenceNumber() else { return }

        var merged = metadata
        if let provided = metadataProvider?.get() {
            merged.merge(provided) { _, provided in provided }
        }
        if let explicit = event.metadata {
            merged.merge(explicit) { _, explicit in explicit }
        }
        let fileName = event.file.split(separator: "/").last.map(String.init) ?? event.file
        let line = ArchiveLogFile.Line(t: Date.now.formatted(ArchiveLogFile.timestampStyle),
                                       seq: sequenceNumber,
                                       session: file.session,
                                       lvl: event.level.rawValue,
                                       label: label,
                                       msg: event.message.description,
                                       meta: merged.mapValues(\.description),
                                       src: "\(fileName):\(event.line) \(event.function)",
                                       error: event.error.map(LogRedact.describe))
        guard let json = ArchiveLogFile.json(line) else { return }
        file.append(json)
    }
}

/// The one place that writes to `<archive>/logs/<device>/`: one JSON object per line, one file per
/// process, continued in `_2`, `_3` … once a file reaches ``maximumFileSize``.
///
/// OSLog cannot answer what a background launch did: `OSLogStore` only reads the running process
/// and drops `debug`. These files survive both, and sync to the Mac with the archive.
final class ArchiveLogFile: Sendable, Log {
    struct Line: Encodable {
        let t: String
        let seq: Int
        let session: String
        let lvl: String
        let label: String
        let msg: String
        let meta: [String: String]
        let src: String
        let error: String?
    }

    private struct State {
        var isEnabled = false
        var sequenceNumber = 0
        var header = Data()
        var directory: URL?
        var handle: FileHandle?
        var fileIndex = 1
        var fileSize = 0
        var bufferedLines: [Data] = []
        var resolution: Task<Void, Never>?
    }

    static let shared = ArchiveLogFile { try await archiveLogsDirectory() }

    static let timestampStyle = Date.ISO8601FormatStyle(timeZoneSeparator: .colon,
                                                        includingFractionalSeconds: true,
                                                        timeZone: .current)

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    /// Tells the lines and files of one process apart from the next launch's.
    let session = String(UUID().uuidString.prefix(6))
    let maximumFileSize: Int

    private let fileNamePrefix: String
    private let resolveDirectory: @Sendable () async throws -> URL
    // A lock, not an actor: `LogHandler.log` is synchronous and runs on any thread, and a line has
    // to be in the page cache, in order, before the caller's next step - that survives a crash.
    private let state = Mutex(State())

    init(maximumFileSize: Int = 1_000_000, resolveDirectory: @escaping @Sendable () async throws -> URL) {
        self.maximumFileSize = maximumFileSize
        self.resolveDirectory = resolveDirectory
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        fileNamePrefix = "\(formatter.string(from: .now))_\(session)"
    }

    /// `nil` while switched off, which keeps the cost of a log line to this one check.
    func nextSequenceNumber() -> Int? {
        state.withLock { state in
            guard state.isEnabled else { return nil }
            state.sequenceNumber += 1
            return state.sequenceNumber
        }
    }

    func append(_ json: Data) {
        var line = json
        line.append(0x0A)
        let failure = state.withLock { state -> (any Error)? in
            guard state.isEnabled else { return nil }
            guard state.handle != nil else {
                Self.buffer(line, in: &state)
                return nil
            }
            do {
                try write(line, in: &state)
                return nil
            } catch {
                // Back to buffering until the folder resolves again, e.g. after iCloud evicted it.
                state.handle = nil
                Self.buffer(line, in: &state)
                startResolving(in: &state)
                return error
            }
        }
        if let failure {
            Self.log.error("Could not write the diagnostic log", metadata: ["error": "\(LogRedact.describe(failure))"])
        }
    }

    /// Starts collecting lines at once; the returned task opens the file and writes what arrived
    /// meanwhile. `nil` when already on.
    @discardableResult
    func enable(header: Data) -> Task<Void, Never>? {
        state.withLock { state in
            guard !state.isEnabled else { return nil }
            state.isEnabled = true
            state.header = header
            state.header.append(0x0A)
            return startResolving(in: &state)
        }
    }

    func disable() {
        let failure = state.withLock { state -> (any Error)? in
            state.isEnabled = false
            state.resolution?.cancel()
            state.resolution = nil
            state.directory = nil
            state.bufferedLines.removeAll()
            defer { state.handle = nil }
            do {
                try state.handle?.close()
                return nil
            } catch {
                return error
            }
        }
        if let failure {
            Self.log.error("Could not close the diagnostic log", metadata: ["error": "\(LogRedact.describe(failure))"])
        }
    }

    static func deviceFolderName(name: String, model: String) -> String {
        "\(name) (\(model))"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    /// `nil` only for a programmer error: a line is made of strings and integers.
    static func json(_ value: some Encodable) -> Data? {
        do {
            return try encoder.encode(value)
        } catch {
            assertionFailure("A diagnostic log line failed to encode: \(error)")
            return nil
        }
    }

    // MARK: - Locked

    private static func buffer(_ line: Data, in state: inout State) {
        state.bufferedLines.append(line)
        // Only reached while the folder cannot be resolved, so the oldest lines give way.
        if state.bufferedLines.count > 5000 {
            state.bufferedLines.removeFirst()
        }
    }

    @discardableResult
    private func startResolving(in state: inout State) -> Task<Void, Never> {
        state.resolution?.cancel()
        let resolution = Task { await resolveTarget() }
        state.resolution = resolution
        return resolution
    }

    private func write(_ line: Data, in state: inout State) throws {
        if state.fileSize > state.header.count, state.fileSize + line.count > maximumFileSize {
            try state.handle?.close()
            state.handle = nil
            state.fileIndex += 1
            try openFile(in: &state)
        }
        try state.handle?.write(contentsOf: line)
        state.fileSize += line.count
    }

    /// Appends only: an atomic replace is a new file every time, and in local storage every new
    /// file makes the folder watcher rescan the archive.
    private func openFile(in state: inout State) throws {
        guard let directory = state.directory else { return }
        let suffix = state.fileIndex == 1 ? "" : "_\(state.fileIndex)"
        let url = directory.appendingPathComponent("\(fileNamePrefix)\(suffix).jsonl")
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        let handle = try FileHandle(forWritingTo: url)
        state.handle = handle
        state.fileSize = Int(try handle.seekToEnd())
        guard state.fileSize == 0 else { return }
        try handle.write(contentsOf: state.header)
        state.fileSize = state.header.count
    }

    private func flushBuffer(in state: inout State) throws {
        var writtenCount = 0
        defer { state.bufferedLines.removeFirst(writtenCount) }
        for line in state.bufferedLines {
            try write(line, in: &state)
            writtenCount += 1
        }
    }

    // MARK: - Target

    private func resolveTarget() async {
        while !Task.isCancelled {
            do {
                let directory = try await resolveDirectory()
                try state.withLock { state in
                    guard state.isEnabled, !Task.isCancelled else { return }
                    state.directory = directory
                    do {
                        try openFile(in: &state)
                        try flushBuffer(in: &state)
                        state.resolution = nil
                    } catch {
                        state.handle = nil
                        throw error
                    }
                }
                return
            } catch {
                Self.log.error("Could not open the diagnostic log", metadata: ["error": "\(LogRedact.describe(error))"])
            }
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return
            }
        }
    }

    /// `<archive>/logs/<device>/`, next to `untagged`.
    private static func archiveLogsDirectory() async throws -> URL {
        let archive = try await ArchiveStore.shared.getUntaggedUrl().deletingLastPathComponent()
        let directory = archive
            .appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent(await deviceFolderName(), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

// MARK: - Setting

extension ArchiveLogFile {
    /// Follows `diagnosticLogsEnabled` for the life of the process.
    @MainActor
    func observeSetting() async {
        @Shared(.diagnosticLogsEnabled) var diagnosticLogsEnabled
        for await isEnabled in $diagnosticLogsEnabled.publisher.removeDuplicates().values {
            if isEnabled {
                enable(header: Self.sessionHeader(session: session))
                DiagnosticSignals.start()
            } else {
                disable()
                DiagnosticSignals.stop()
            }
        }
    }

    /// The first line of every file: which build and hardware wrote it, and whether the process
    /// started in the background.
    @MainActor
    private static func sessionHeader(session: String) -> Data {
        let info = Bundle.main.infoDictionary
        #if os(iOS)
        let platform = UIDevice.current.systemName
        #else
        let platform = "macOS"
        #endif
        let header = [
            "t": Date.now.formatted(timestampStyle),
            "session": session,
            "version": info?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": info?["CFBundleVersion"] as? String ?? "unknown",
            "os": "\(platform) \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "model": hardwareModel(),
            "launchState": DiagnosticSignals.applicationState()
        ]
        return json(header) ?? Data()
    }

    @MainActor
    private static func deviceFolderName() -> String {
        #if os(iOS)
        deviceFolderName(name: UIDevice.current.name, model: hardwareModel())
        #else
        deviceFolderName(name: Host.current().localizedName ?? "Mac", model: hardwareModel())
        #endif
    }

    /// `iPhone18,1` on iOS; on macOS `hw.machine` is only the CPU architecture, so `hw.model`.
    private static func hardwareModel() -> String {
        #if os(iOS)
        let name = "hw.machine"
        #else
        let name = "hw.model"
        #endif
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(bytes: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? "unknown"
    }
}
