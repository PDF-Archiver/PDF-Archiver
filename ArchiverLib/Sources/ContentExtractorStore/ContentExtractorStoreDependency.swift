//
//  ContentExtractorStoreDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverModels
import ComposableArchitecture
import Foundation

@DependencyClient
public struct ContentExtractorStoreDependency: Sendable {
    public struct DocInfo: Sendable {
    }

    @available(iOS 26, macOS 26, *)
    private static let contentExtractorStore = ContentExtractorStore()

    public var getDocumentInformation: @Sendable (String) async throws -> DocInfo?

//    #if canImport(FoundationModels)
//    public var instructions: @Sendable () async -> AsyncStream<[Document]> = { AsyncStream<[Document]> { $0.yield([]) } }
//    #endif
}

extension ContentExtractorStoreDependency: TestDependencyKey {
    public static let previewValue = Self(
        getDocumentInformation: { _ in nil },
//        #if canImport(FoundationModels)
//        instructions: {
//            AsyncStream { stream in
//                Task {
////                    stream.yield([
////                    ])
//                }
//            }
//        },
//        #endif
    )

    public static let testValue = Self()
}

extension ContentExtractorStoreDependency: DependencyKey {
    public static let liveValue = ContentExtractorStoreDependency(
        getDocumentInformation: { text in
            guard #available(iOS 26.0, macOS 26.0, *) else { return nil }
            #warning("TODO: fix this")
            let result = try await contentExtractorStore.extract(from: text)

            #warning("TODO: fix this")
            return DocInfo()
        },
    )
}

public extension DependencyValues {
    var contentExtractorStore: ContentExtractorStoreDependency {
        get { self[ContentExtractorStoreDependency.self] }
        set { self[ContentExtractorStoreDependency.self] = newValue }
    }
}
