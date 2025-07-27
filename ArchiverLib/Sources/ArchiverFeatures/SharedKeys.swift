//
//  SharedKeys.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 08.07.25.
//

import ArchiverModels
import ComposableArchitecture

extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<Document>> {
  static var documents: Self {
      fileStorage(.temporaryDirectory.appending(component: "documents.json"))
  }
}

extension SharedReaderKey where Self == InMemoryKey<Int?> {
  static var selectedDocumentId: Self {
    inMemory("selectedDocumentId")
  }
}
