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
@MainActor
func createMockData(in modelContext: ModelContext) {
    let examplePdfUrl = Bundle.main.resourceURL!.appendingPathComponent("example-bill.pdf", conformingTo: .pdf)
    
    modelContext.insert(DBDocument(id: "debug-document-id", url: examplePdfUrl, isTagged: true, filename: "test", date: Date(), specification: "macbook pro", tags: ["bill", "longterm"], downloadStatus: 0))
    modelContext.insert(DBDocument(id: "error", url: URL(filePath: "/tmp/invalid-path.pdf"), isTagged: true, filename: "test", date: Date(), specification: "tv board", tags: ["bill", "home", "ikea"], downloadStatus: 0.25))
    modelContext.insert(DBDocument(id: UUID().uuidString, url: URL(filePath: ""), isTagged: true, filename: "test", date: Date(), specification: "large picture", tags: ["bill", "ikea"], downloadStatus: 0.5))
    modelContext.insert(DBDocument(id: UUID().uuidString, url: URL(filePath: ""), isTagged: true, filename: "test", date: Date(), specification: "coffee bags", tags: ["bill", "coffee"], downloadStatus: 0.75))
    modelContext.insert(DBDocument(id: UUID().uuidString, url: URL(filePath: ""), isTagged: true, filename: "test", date: Date(), specification: "tools", tags: ["bill"], downloadStatus: 1))
    modelContext.insert(DBDocument(id: UUID().uuidString, url: URL(filePath: ""), isTagged: false, filename: "scan1", date: Date(), specification: "", tags: [], downloadStatus: 1))
    modelContext.insert(DBDocument(id: UUID().uuidString, url: URL(filePath: ""), isTagged: false, filename: "scan2", date: Date(), specification: "", tags: [], downloadStatus: 1))
}

@MainActor
let previewContainer: ModelContainer = {
    let container = createContainer(isStoredInMemoryOnly: true)
    createMockData(in: container.mainContext)
    return container
}()
#endif

func createContainer(isStoredInMemoryOnly: Bool) -> ModelContainer {
    let schema = Schema([
        DBDocument.self
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
