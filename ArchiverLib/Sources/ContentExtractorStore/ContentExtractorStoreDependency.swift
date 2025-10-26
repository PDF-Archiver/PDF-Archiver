//
//  ContentExtractorStoreDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ComposableArchitecture
import Foundation
import OSLog
import Shared
import ArchiverStore

@DependencyClient
public struct ContentExtractorStoreDependency: Sendable {
    @Dependency(\.archiveStore) var archiveStore
    
    public struct DocInfoInput: Sendable {
        public let currentDocuments: [Document]
        public let text: String
        public let customPrompt: String?

        public init(currentDocuments: [Document], text: String, customPrompt: String?) {
            self.currentDocuments = currentDocuments
            self.text = text
            self.customPrompt = customPrompt
        }
    }
    public struct DocInfo: Sendable {
        public let specification: String
        public let tags: Set<String>
    }

    @available(iOS 26, macOS 26, *)
    private static let contentExtractorStore = ContentExtractorStore()

    public var isAvailable: @Sendable () async -> AppleIntelligenceAvailability = { .operatingSystemNotCompatible }
    public var getDocumentInformation: @Sendable (DocInfoInput) async -> DocInfo?
}

extension ContentExtractorStoreDependency: TestDependencyKey {
    public static let previewValue = Self(
        isAvailable: { .available },
        getDocumentInformation: { _ in nil }
    )

    public static let testValue = Self()
}

extension ContentExtractorStoreDependency: DependencyKey {
    public static let liveValue = ContentExtractorStoreDependency(
        isAvailable: {
            guard #available(iOS 26.0, macOS 26.0, *) else {
                return .operatingSystemNotCompatible
            }

            return ContentExtractorStore.getAvailability()
        },
        getDocumentInformation: { input in
            guard #available(iOS 26.0, macOS 26.0, *) else { return nil }
            do {
                guard let result = try await contentExtractorStore.extract(from: input.text,
                                                                           customPrompt: input.customPrompt,
                                                                           with: input.currentDocuments) else { return nil }

                return DocInfo(specification: result.specification,
                               tags: Set(result.tags))
            } catch {
                Logger.contentExtractor.errorAndAssert("An error occurred while extracting document content", metadata: ["error": "\(error)"])
                return nil
            }
        }
    )
}

public extension DependencyValues {
    var contentExtractorStore: ContentExtractorStoreDependency {
        get { self[ContentExtractorStoreDependency.self] }
        set { self[ContentExtractorStoreDependency.self] = newValue }
    }
}
