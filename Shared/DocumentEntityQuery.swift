//
//  DocumentEntityQuery.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 19.03.26.
//

import AppIntents
import ArchiverModels
import Foundation
import Shared

/// Provides entity lookup and search for DocumentEntity used by Shortcuts and Siri.
///
/// Reads documents from the file cache populated by AppFeature.
public struct DocumentEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [DocumentEntity.ID]) async throws -> [DocumentEntity] {
        let identifierSet = Set(identifiers)
        return loadDocuments()
            .filter { identifierSet.contains($0.id) }
            .map { DocumentEntity(document: $0) }
    }

    public func suggestedEntities() async throws -> [DocumentEntity] {
        loadDocuments()
            .filter(\.isTagged)
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map { DocumentEntity(document: $0) }
    }

    // Reads documents from the shared file cache written by AppFeature.
    private func loadDocuments() -> [Document] {
        let fileURL = documentsFileURL
        guard let data = try? Data(contentsOf: fileURL),
              let documents = try? JSONDecoder().decode([Document].self, from: data) else {
            return []
        }
        return documents
    }
}

extension DocumentEntityQuery: EntityStringQuery {
    public func entities(matching string: String) async throws -> [DocumentEntity] {
        loadDocuments()
            .filter { $0.url.lastPathComponent.localizedCaseInsensitiveContains(string) }
            .map { DocumentEntity(document: $0) }
    }
}
