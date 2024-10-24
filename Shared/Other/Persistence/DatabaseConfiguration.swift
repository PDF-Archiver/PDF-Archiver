//
//  DatabaseConfiguration.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 15.03.24.
//

import Foundation
import SwiftData

let container = {
    createContainer(isStoredInMemoryOnly: true)
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

    modelContext.insert(Document(id: "debug-document-id", url: examplePdfUrl, isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "macbook pro", tags: [bill, longterm], content: "", downloadStatus: 0))
    modelContext.insert(Document(id: "error", url: URL(filePath: "/tmp/invalid-path.pdf"), isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "tv board", tags: [bill, home, ikea], content: "", downloadStatus: 0.25))
    modelContext.insert(Document(id: UUID().uuidString, url: URL(filePath: ""), isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "large picture", tags: [bill, ikea], content: "", downloadStatus: 0.5))
    modelContext.insert(Document(id: UUID().uuidString, url: URL(filePath: ""), isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "coffee bags", tags: [bill, coffee], content: "", downloadStatus: 0.75))
    modelContext.insert(Document(id: UUID().uuidString, url: URL(filePath: ""), isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "tools", tags: [bill], content: "", downloadStatus: 1))
    modelContext.insert(Document(id: UUID().uuidString, url: URL(filePath: ""), isTagged: false, filename: "scan1", sizeInBytes: 128, date: Date(), specification: "", tags: [], content: "", downloadStatus: 1))
    modelContext.insert(Document(id: UUID().uuidString, url: URL(filePath: ""), isTagged: false, filename: "scan2", sizeInBytes: 128, date: Date(), specification: "", tags: [], content: "", downloadStatus: 1))
}

@MainActor
func previewContainer(documents: [(id: String, downloadStatus: Double)] = []) -> ModelContainer {
    let container = createContainer(isStoredInMemoryOnly: true)
    createMockData(in: container.mainContext)

    let bill = Tag(name: "bill", documents: [])
    let longterm = Tag(name: "longterm", documents: [])
    for document in documents {
        container.mainContext.insert(Document(id: document.id, url: examplePdfUrl, isTagged: true, filename: "test", sizeInBytes: 128, date: Date(), specification: "macbook pro", tags: [bill, longterm], content: "", downloadStatus: document.downloadStatus))
    }
    return container
}
#endif

func createContainer(isStoredInMemoryOnly: Bool) -> ModelContainer {
    let schema = Schema([
        Document.self
    ])
    let url = URL.documentsDirectory.appending(path: "EcoStats.default")

    let configuration: ModelConfiguration
    if isStoredInMemoryOnly {
        configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly, cloudKitDatabase: .none)
    } else {
        configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    }

    do {
//        #if DEBUG
//        try initializeDevelopmentCloudKit(url)
//        #endif

        return try ModelContainer(
            for: schema,
            configurations: configuration
        )
    } catch {
        preconditionFailure("Could not create ModelContainer: \(error)")
    }
}
