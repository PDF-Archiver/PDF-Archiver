//
//  DocumentProcessingDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.25.
//

import ArchiverDocumentProcessing
import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Foundation
import Shared

@DependencyClient
struct DocumentProcessingDependency {
    var run: @Sendable () async -> Void
}

extension DocumentProcessingDependency: TestDependencyKey {
    static let previewValue = Self(
        run: { }
    )

    static let testValue = Self()
}

extension DocumentProcessingDependency: DependencyKey {
  static let liveValue = DocumentProcessingDependency(
    run: {
        let service = await DocumentProcessingService(tempDocumentURL: Constants.tempDocumentURL,
                                                      documentDestination: {
            try await PathManager.shared.getUntaggedUrl()
        })

        await service.runObservation()
    }
  )
}

extension DependencyValues {
  var documentProcessor: DocumentProcessingDependency {
    get { self[DocumentProcessingDependency.self] }
    set { self[DocumentProcessingDependency.self] = newValue }
  }
}
