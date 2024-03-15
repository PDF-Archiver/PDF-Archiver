//
//  File.swift
//  
//
//  Created by Julian Kahnert on 14.03.24.
//

import Foundation
import SwiftData
import Logging

let container = {
    let schema = Schema([
        DBDocument.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

    return try! ModelContainer(
        for: schema,
        configurations: configuration
    )
}()

actor SearchArchive: ModelActor, Log {

    static let shared = SearchArchive(modelContainer: container)

    // https://useyourloaf.com/blog/swiftdata-background-tasks/
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // "Apple warns you not to use the model executor to access the model context. Instead you should use the modelContext property of the actor."
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        log.trace("[SearchArchive] init called")
    }

    func addDocument(id: String, date: Date, specification: String, downloadstatus: Double) throws {
        let document = DBDocument(id: id, date: date, specification: specification, tags: [], downloadStatus: downloadstatus)
        modelContext.insert(document)

        try modelContext.save()
    }
}
