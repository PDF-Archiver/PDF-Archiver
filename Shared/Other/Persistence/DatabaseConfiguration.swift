//
//  DatabaseConfiguration.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 15.03.24.
//

import Foundation
import SwiftData

let container = {
    func getDbURL(with version: Int) -> URL {
        return URL.applicationSupportDirectory.appendingPathComponent("pdf-archiver-\(version).sqlite")
    }

    do {
        let version = 1

        // delete old DB is it exists
        let oldDbUrl = getDbURL(with: version - 1)
        if FileManager.default.fileExists(at: oldDbUrl) {
            try? FileManager.default.removeItem(at: oldDbUrl)
        }

        // create new DB config
        let dbUrl = getDbURL(with: version)
//        return try ModelContainer(for: Document.self, configurations: .init(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return try ModelContainer(for: Document.self, configurations: .init(url: dbUrl, cloudKitDatabase: .none))
    } catch {
        preconditionFailure("Could not create ModelContainer: \(error)")
    }
}()

#if DEBUG
let examplePdfUrl = Bundle.main.resourceURL!.appendingPathComponent("example-bill.pdf", conformingTo: .pdf)

@MainActor
func createMockData(in modelContext: ModelContext) {
    let bill = Tag(name: "bill", documents: [])
    let longterm = Tag(name: "longterm", documents: [])
    let home = Tag(name: "home", documents: [])
    let ikea = Tag(name: "ikea", documents: [])
    let coffee = Tag(name: "coffee", documents: [])

    modelContext.insert(Document(id: 1, url: examplePdfUrl, isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "macbook pro", tags: [bill, longterm], content: "", downloadStatus: 0, created: Date()))
    modelContext.insert(Document(id: 2, url: URL(filePath: "/tmp/invalid-path.pdf"), isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "tv board", tags: [bill, home, ikea], content: "", downloadStatus: 0.25, created: Date()))
    modelContext.insert(Document(id: 3, url: URL(filePath: ""), isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "large picture", tags: [bill, ikea], content: "", downloadStatus: 0.5, created: Date()))
    modelContext.insert(Document(id: 4, url: URL(filePath: ""), isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "coffee bags", tags: [bill, coffee], content: "", downloadStatus: 0.75, created: Date()))
    modelContext.insert(Document(id: 5, url: URL(filePath: ""), isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "tools", tags: [bill], content: "", downloadStatus: 1, created: Date()))
    modelContext.insert(Document(id: 6, url: URL(filePath: ""), isTagged: false, filename: "scan1", sizeInBytes: 128, date: Date(), specification: "", tags: [], content: "", downloadStatus: 1, created: Date()))
    modelContext.insert(Document(id: 7, url: URL(filePath: ""), isTagged: false, filename: "scan2", sizeInBytes: 128, date: Date(), specification: "", tags: [], content: "", downloadStatus: 1, created: Date()))
}

@MainActor
func previewContainer(documents: [(id: Int, downloadStatus: Double)] = []) -> ModelContainer {
    createMockData(in: container.mainContext)

    let bill = Tag(name: "bill", documents: [])
    let longterm = Tag(name: "longterm", documents: [])
    for document in documents {
        container.mainContext.insert(Document(id: document.id, url: examplePdfUrl, isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "macbook pro", tags: [bill, longterm], content: "", downloadStatus: document.downloadStatus, created: Date()))
    }
    return container
}
#endif
