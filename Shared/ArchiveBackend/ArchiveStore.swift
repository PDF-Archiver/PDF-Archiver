//
//  ArchiveStore.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 24.06.20.
//

import Combine
import Foundation
// TODO: Move archive search to separate package

public protocol ArchiveStoreAPI: AnyObject {
    var documents: [Document] { get }
    var documentsPublisher: AnyPublisher<[Document], Never> { get }

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

    private static let availableProvider: [FolderProvider.Type] = {
        if UserDefaults.isInDemoMode {
            return [DemoFolderProvider.self]
        } else {
            return [ICloudFolderProvider.self, LocalFolderProvider.self]
        }
    }()

    private static let fileProperties: [URLResourceKey] = [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey, .fileSizeKey, .localizedNameKey]
    private static let savePath: URL = {
        guard let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { fatalError("No cache dir found.") }
        return url.appendingPathComponent("ArchiveData.json")
    }()
    public static let shared = ArchiveStore()

    @Published public var state: State = .uninitialized
    @Published public var documents: [Document] = []
    @Published public var years: Set<String> = []

    public var documentsPublisher: AnyPublisher<[Document], Never> {
        $documents.eraseToAnyPublisher()
    }

    private var archiveFolder: URL!
    private var untaggedFolders: [URL] = []

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ArchiveStoreQueue", qos: .userInitiated)
    private let queueBackground = DispatchQueue(label: "ArchiveStoreQueue-background", qos: .background)
    private let documentProcessingQueue = DispatchQueue(label: "ArchiveStore DocumentProcessing queue", qos: .userInitiated, attributes: .concurrent)

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

        // remove all current file providers to prevent watching changes while moving folders
        providers = []

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

        providers = observedFolders.compactMap { folder in
            guard let provider = Self.availableProvider.first(where: { $0.canHandle(folder) }) else {
                log.errorAndAssert("Could not find a FolderProvider", metadata: ["path": "\(folder.path)"])
                NotificationCenter.default.createAndPost(title: "Folder Provider Error", message: "Could not find a folder provider for path:\n\(folder.absoluteString)", primaryButtonTitle: "OK")
                return nil
            }
            log.debug("Initialize new provider for: \(folder.path)")
            do {
                return try provider.init(baseUrl: folder, folderDidChange(_:_:))
            } catch {
                log.error("Failed to create FolderProvider.", metadata: ["error": "\(error)"])
                NotificationCenter.default.postAlert(error)
                return nil
            }
        }
    }

    public func archive(_ document: Document, slugify: Bool) throws {
        assert(!Thread.isMainThread, "This should not be called from the main thread.")

        guard let archiveFolder = self.archiveFolder else {
            throw ArchiveStore.Error.providerNotFound
        }
        let documentProvider = try getProvider(for: document.path)
        let archiveProvider = try getProvider(for: archiveFolder)

        if slugify {
            document.specification = document.specification.slugified(withSeparator: "-")
        }

        // create a filename and rename the document
        guard let date = document.date else {
            throw FolderProviderError.date
        }
        guard !document.tags.isEmpty || UserDefaults.documentTagsNotRequired else {
            throw FolderProviderError.tags
        }
        guard !document.specification.isEmpty || UserDefaults.documentSpecificationNotRequired else {
            throw FolderProviderError.description
        }

        let filename = Document.createFilename(date: date, specification: document.specification, tags: document.tags)
        let foldername = String(filename.prefix(4))

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
        newFilepath.setFileTags(document.tags.sorted())
    }

    public func download(_ document: Document) throws {
        let provider = try getProvider(for: document.path)

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

        let provider = try getProvider(for: document.path)
        try provider.delete(url: document.path)
        documents.removeAll { $0 == document }
    }

    public func getCreationDate(of url: URL) throws -> Date? {
        let provider = try getProvider(for: url)

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
                let updateDocumentProperties: Bool

                switch change {
                    case .added(let details):
                        let taggingStatus = getTaggingStatus(of: details.url)
                        document = Document(from: details, with: taggingStatus)
                        updateDocumentProperties = true

                        // document content will be parsed if the user selects the untagged document in the Tag tab
//                    SearchArchive.shared.addDocument(<#T##NSDocument#>)

                    case .removed(let url):
                        contents[provider.baseUrl]?.removeAll { $0.path == url }
                        updateDocumentProperties = false

                    case .updated(let details):
                        if let foundDocument = contents[provider.baseUrl]?.first(where: { $0.path == details.url }) {
                            // update details
                            foundDocument.downloadStatus = details.downloadStatus
                            foundDocument.filename = details.filename

                            document = foundDocument
                        } else {
                            let taggingStatus = getTaggingStatus(of: details.url)
                            document = Document(from: details, with: taggingStatus)
                        }

                        contents[provider.baseUrl]?.removeAll { $0.path == details.url }

                        updateDocumentProperties = true
                }

                if let document = document {
                    contents[provider.baseUrl, default: []].append(document)

                    // trigger update of the document properties
                    if updateDocumentProperties {
                        documentProcessingGroup.enter()
                        documentProcessingQueue.async {
                            // save documents after the last has been written
                            document.updateProperties(with: document.downloadStatus)
                            documentProcessingGroup.leave()
                        }
                    }
                }
            }

            for url in contents.keys {
                contents[url]?.sort()
            }
        }

        // We have to wait until all documents have been processed, because several updates will be triggered on $document changes
        // these changes must contain the valid new information.
        queueBackground.async {
            let timeout = documentProcessingGroup.wait(wallTimeout: .now() + .seconds(60))
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
                .flatMap(\.value)
                .sorted()
        }
        self.documents = documents

        updateYears()

        log.info("Found \(documents.count) documents.")
        state = .live
        save(documents)
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
        guard !untaggedFolders.contains(where: { url.path.contains($0.path) }) else { return .untagged }

        // Do "--" and "__" exist in filename?
        guard url.lastPathComponent.contains("--"),
            url.lastPathComponent.contains("__"),
            !url.lastPathComponent.lowercased().contains(Constants.documentDatePlaceholder.lowercased()),
            !url.lastPathComponent.lowercased().contains(Constants.documentDescriptionPlaceholder.lowercased()),
            !url.lastPathComponent.lowercased().contains(Constants.documentTagPlaceholder.lowercased()) else { return .untagged }

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

    private func save(_ documents: [Document]) {

        if fileManager.fileExists(atPath: Self.savePath.path) {
            try? fileManager.removeItem(at: Self.savePath)
        }

        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: Self.savePath)
        } catch {
            log.error("JSON encoding error", metadata: ["error": "\(error)"])
        }
    }

    private func getProvider(for url: URL) throws -> FolderProvider {

        // Use `contains` instead of `prefix` to avoid problems with local files.
        // This fixes a problem, where we get different file urls back:
        // /private/var/mobile/Containers/Data/Application/8F70A72B-026D-4F6B-98E8-2C6ACE940133/Documents/untagged/document1.pdf
        //         /var/mobile/Containers/Data/Application/8F70A72B-026D-4F6B-98E8-2C6ACE940133/Documents/

        guard let provider = providers.first(where: { url.path.contains($0.baseUrl.path) }) else {
            throw ArchiveStore.Error.providerNotFound
        }

        return provider
    }
}
