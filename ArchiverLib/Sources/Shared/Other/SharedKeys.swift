//
//  SharedKeys.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 08.07.25.
//

import ArchiverModels
import ComposableArchitecture

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<Document>> {
  static var documents: Self {
      fileStorage(.temporaryDirectory.appending(component: "documents.json"))
  }
}

public extension SharedReaderKey where Self == AppStorageKey<Bool> {
  static var tutorialShown: Self {
      appStorage("tutorial-v1", store: .standard)
  }
}

public extension SharedReaderKey where Self == AppStorageKey<PDFQuality> {
    static var pdfQuality: Self {
        appStorage("pdfQuality", store: .standard)
    }
}

public extension SharedReaderKey where Self == AppStorageKey<StorageType> {
    static var archivePathType: Self {
        appStorage("archivePathType", store: .standard)
    }
}

public extension SharedReaderKey where Self == InMemoryKey<PremiumStatus> {
    static var premiumStatus: Self {
        inMemory("premiumStatus")
    }
}

public extension SharedReaderKey where Self == InMemoryKey<Int?> {
    static var selectedDocumentId: Self {
        inMemory("selectedDocumentId")
    }
}
