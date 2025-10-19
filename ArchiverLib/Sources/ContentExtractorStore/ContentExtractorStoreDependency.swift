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

@DependencyClient
public struct ContentExtractorStoreDependency: Sendable {
    public struct DocInfo: Sendable {
        public let specification: String
        public let tags: Set<String>
    }

    @available(iOS 26, macOS 26, *)
    private static let contentExtractorStore = ContentExtractorStore()

    public var isAvailable: @Sendable () async -> AppleIntelligenceAvailability = { .deviceNotCompatible }
    public var prewarm: @Sendable () async -> Void
    public var getDocumentInformation: @Sendable (String) async -> DocInfo?
}

extension ContentExtractorStoreDependency: TestDependencyKey {
    public static let previewValue = Self(
        isAvailable: { .available },
        prewarm: {},
        getDocumentInformation: { _ in nil }
    )

    public static let testValue = Self()
}

extension ContentExtractorStoreDependency: DependencyKey {
    public static let liveValue = ContentExtractorStoreDependency(
        isAvailable: {
            guard #available(iOS 26.0, macOS 26.0, *) else {
                return .deviceNotCompatible
            }

            return ContentExtractorStore.getAvailability()
        },
        prewarm: {
            guard #available(iOS 26.0, macOS 26.0, *) else { return }
            await contentExtractorStore.prewarm()
        },
        getDocumentInformation: { text in
            guard #available(iOS 26.0, macOS 26.0, *) else { return nil }
            do {
                guard let result = try await contentExtractorStore.extract(from: text) else { return nil }

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
