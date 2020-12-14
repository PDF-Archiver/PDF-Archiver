//
//  ArchiveStore.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.06.20.
//

import Combine
import Foundation

public protocol ArchiveStoreAPI: class {
    func update(archiveFolder: URL, untaggedFolders: [URL])
    func archive(_ document: Document, slugify: Bool) throws
    func download(_ document: Document) throws
    func delete(_ document: Document) throws
    func getCreationDate(of url: URL) throws -> Date?
}

public final class ArchiveStore: ObservableObject, ArchiveStoreAPI, Log {

    public enum State {
        case uninitialized, cachedDocuments, live
    }

    private static let availableProvider: [FolderProvider.Type] = [
        ICloudFolderProvider.self,
        LocalFolderProvider.self
    ]

    private static let fileProperties: [URLResourceKey] = [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey, .fileSizeKey, .localizedNameKey]
    private static let savePath: URL = {
        guard let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { fatalError("No cache dir found.") }
        return url.appendingPathComponent("ArchiveData.json")
    }()
    public static let shared = ArchiveStore()

    @Published public var state: State = .uninitialized
    @Published public var documents: [Document] = []
    @Published public var years: Set<String> = []

    private var archiveFolder: URL!
    private var untaggedFolders: [URL] = []

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ArchiveStoreQueue", qos: .utility)
    private var providers: [FolderProvider] = []
    private var contents: [URL: [Document]] = [:]

    private init() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.loadDocuments()
        }
    }

    // MARK: Public API

    public func update(archiveFolder: URL, untaggedFolders: [URL]) {
        assert(!Thread.isMainThread, "This should not be called from the main thread.")

        let oldArchiveFolder = self.archiveFolder

        self.archiveFolder = archiveFolder
        self.untaggedFolders = untaggedFolders
        let observedFolders = [[archiveFolder], untaggedFolders]
            .flatMap { $0 }
            .getUniqueParents()

        queue.sync {
            contents = [:]
        }

        if let oldArchiveFolder = oldArchiveFolder,
           oldArchiveFolder != archiveFolder {
            // only remove this if the archiveFolder has changed
            try? fileManager.removeItem(at: Self.savePath)
        }

        providers = observedFolders.map { folder in
            guard let provider = Self.availableProvider.first(where: { $0.canHandle(folder) }) else {
                preconditionFailure("Could not find a FolderProvider for: \(folder.path)")
            }
            return provider.init(baseUrl: folder, folderDidChange(_:_:))
        }
    }

    public func archive(_ document: Document, slugify: Bool) throws {
        assert(!Thread.isMainThread, "This should not be called from the main thread.")

        guard let documentProvider = providers.first(where: { document.path.path.hasPrefix($0.baseUrl.path) }),
              let archiveFolder = self.archiveFolder,
              let archiveProvider = providers.first(where: { archiveFolder.path.hasPrefix($0.baseUrl.path) }) else {
            throw ArchiveStore.Error.providerNotFound
        }

        if slugify {
            DispatchQueue.main.async {
                document.specification = document.specification.slugified(withSeparator: "-")
            }
        }

        let foldername: String
        let filename: String
        (foldername, filename) = try document.getRenamingPath()

        // check, if this path already exists ... create it
        let newFilepath = archiveFolder
            .appendingPathComponent(foldername)
            .appendingPathComponent(filename)

        if archiveProvider.baseUrl == documentProvider.baseUrl {
            try archiveProvider.rename(from: document.path, to: newFilepath)
        } else {
            let documentData = try documentProvider.fetch(url: document.path)
            try archiveProvider.save(data: documentData, at: newFilepath)
            try documentProvider.delete(url: document.path)
        }

        // update document properties
        document.filename = String(newFilepath.lastPathComponent)
        document.path = newFilepath
        document.taggingStatus = .tagged

        // save file tags
        document.path.fileTags = document.tags.sorted()
    }

    public func download(_ document: Document) throws {
        guard let provider = providers.first(where: { document.path.path.hasPrefix($0.baseUrl.path) }) else {
            throw ArchiveStore.Error.providerNotFound
        }

        guard document.downloadStatus == .remote else { return }

        do {
            try provider.startDownload(of: document.path)
            document.downloadStatus = .downloading(percent: 0)
        } catch {
            log.errorAndAssert("Document download error.", metadata: ["error": "\(error)"])
            throw error
        }
    }

    public func delete(_ document: Document) throws {
        assert(!Thread.isMainThread, "This should not be called from the main thread.")

        guard let provider = providers.first(where: { document.path.path.hasPrefix($0.baseUrl.path) }) else {
            throw ArchiveStore.Error.providerNotFound
        }
        try provider.delete(url: document.path)
        documents.removeAll { $0 == document }
    }

    public func getCreationDate(of url: URL) throws -> Date? {
        guard let provider = providers.first(where: { url.path.hasPrefix($0.baseUrl.path) }) else {
            throw ArchiveStore.Error.providerNotFound
        }

        do {
            return try provider.getCreationDate(of: url)
        } catch {
            log.error("Document download error.", metadata: ["error": "\(error)"])
            throw error
        }
    }

    // MARK: Helper Function

    private func folderDidChange(_ provider: FolderProvider, _ changes: [FileChange]) {

        let documentProcessingGroup = DispatchGroup()

        queue.sync {
            for change in changes {

                var document: Document?
                var contentParsingOptions: ParsingOptions?

                switch change {
                    case .added(let details):
                        let taggingStatus = getTaggingStatus(of: details.url)
                        document = Document(from: details, with: taggingStatus)

                        // parse document content only for untagged documents
                        contentParsingOptions = taggingStatus == .untagged ? .all : []

                    case .removed(let url):
                        contents[provider.baseUrl]?.removeAll { $0.path == url }

                    case .updated(let details):
                        if let foundDocument = contents[provider.baseUrl]?.first(where: { $0.path == details.url }) {
                            // update details
                            DispatchQueue.main.async {
                                foundDocument.downloadStatus = details.downloadStatus
                            }
                            foundDocument.filename = details.filename

                            document = foundDocument
                        } else {
                            let taggingStatus = getTaggingStatus(of: details.url)
                            document = Document(from: details, with: taggingStatus)
                        }

                        contents[provider.baseUrl]?.removeAll { $0.path == details.url }

                        contentParsingOptions = []
                }

                if let document = document {
                    contents[provider.baseUrl, default: []].append(document)
                    contents[provider.baseUrl]?.sort()

                    // trigger update of the document properties
                    if let contentParsingOptions = contentParsingOptions {
                        DispatchQueue.global(qos: .background).async {
                            // save documents after the last has been written
                            documentProcessingGroup.enter()
                            document.updateProperties(with: document.downloadStatus, contentParsingOptions: contentParsingOptions)
                            documentProcessingGroup.leave()
                        }
                    }
                }
            }
        }

        DispatchQueue.global(qos: .background).async {
            let timeout = documentProcessingGroup.wait(wallTimeout: .now() + .seconds(15))
            if timeout == .timedOut {
                Self.log.errorAndAssert("Timeout while waiting for documents to be processed.")
            }
            self.updateDocuments()
        }
    }

    private func updateDocuments() {
        var documents = [Document]()
        queue.sync {
            documents = self.contents
                .flatMap { $0.value }
                .sorted()
        }
        self.documents = documents

        updateYears()

        log.info("Found \(documents.count) documents.")
        self.state = .live
        DispatchQueue.global(qos: .background).async {
            self.saveDocuments()
        }
    }

    private func updateYears() {
        var years = Set<String>()
        for document in self.documents {
            let folder = document.folder
            guard folder.isNumeric,
                  folder.count <= 4 else { continue }
            years.insert(folder)
        }
        self.years = years
    }

    private func getTaggingStatus(of url: URL) -> Document.TaggingStatus {

        // Could document be found in the untagged folder?
        guard untaggedFolders.contains(where: { url.path.contains($0.path) }) else { return .tagged }

        // Do "--" and "__" exist in filename?
        guard url.lastPathComponent.contains("--"),
            url.lastPathComponent.contains("__"),
            !url.lastPathComponent.contains(Constants.documentDatePlaceholder),
            !url.lastPathComponent.contains(Constants.documentDescriptionPlaceholder),
            !url.lastPathComponent.contains(Constants.documentTagPlaceholder) else { return .untagged }

        return .tagged
    }

    // MARK: Load & Save

    private func loadDocuments() {
        guard state == .uninitialized,
              fileManager.fileExists(atPath: Self.savePath.path),
              documents.isEmpty else { return }
        do {
            let data = try Data(contentsOf: Self.savePath)
            let loadedDocuments = try JSONDecoder().decode([Document].self, from: data)
            guard state == .uninitialized,
                  documents.isEmpty else { return }
            documents = loadedDocuments
            state = .cachedDocuments
            log.info("\(documents.count) documents loaded.")

            updateYears()
        } catch {
            log.error("JSON decoding error", metadata: ["error": "\(error)"])

            try? fileManager.removeItem(at: Self.savePath)
        }
    }

    private func saveDocuments() {

        if fileManager.fileExists(atPath: Self.savePath.path) {
            try? fileManager.removeItem(at: Self.savePath)
        }

        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: Self.savePath)
            log.info("Documents saved.")
        } catch {
            log.error("JSON encoding error", metadata: ["error": "\(error)"])
        }
    }
}
