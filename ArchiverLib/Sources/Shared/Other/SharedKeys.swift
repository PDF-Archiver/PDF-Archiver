//
//  SharedKeys.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 08.07.25.
//

import ArchiverModels
import ComposableArchitecture
import Foundation

enum Names: String {
    case tutorialShown = "tutorial-v1"
    case pdfQuality = "pdf-quality"
    case notSaveDocumentTagsAsPDFMetadata = "not-save-document-tags-as-pdf-metadata"
    case documentTagsNotRequired = "document-tags-not-required"
    case documentSpecificationNotRequired = "document-specification-not-required"
    case appleIntelligenceEnabled = "apple-intelligence-enabled"
    case appleIntelligenceCustomPrompt = "apple-intelligence-custom-prompt"
    case appleIntelligenceCacheEnabled = "apple-intelligence-cache-enabled"
    case backgroundCacheNotificationsEnabled = "background-cache-notifications-enabled"
    case multiTagSelectionDelayEnabled = "multi-tag-selection-delay-enabled"
    case ocrEnabled = "ocr-enabled"
    case highlightDetectedDateEnabled = "highlight-detected-date-enabled"

    var id: String { "shared-\(rawValue)" }
}

// MARK: user defaults

/// `true` if the tutorial was already shown
public extension SharedKey where Self == AppStorageKey<Bool> {
  static var tutorialShown: Self {
      appStorage(Names.tutorialShown.id)
  }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var tutorialShown: Self {
      @Dependency(\.defaultAppStorage) var store
      // try to fetch the value from a previous version
      let defaultValue = (store.value(forKey: "tutorial-v1") as? Bool) ?? false
      return Self[.appStorage(Names.tutorialShown.id), default: defaultValue]
  }
}

/// Default quality of a the images that will be processed to a PDF document
public extension SharedKey where Self == AppStorageKey<Float> {
    static var pdfQuality: Self {
        appStorage(Names.pdfQuality.id)
    }
}
public extension SharedKey where Self == AppStorageKey<PDFQuality>.Default {
  static var pdfQuality: Self {
      @Dependency(\.defaultAppStorage) var store
      let defaultValue: PDFQuality

      // try to fetch the value from a previous version
      if let oldValue = store.value(forKey: "pdfQuality") as? Float,
         oldValue != 0,
        let oldPdfQuality = PDFQuality(rawValue: oldValue) {
          defaultValue = oldPdfQuality
      } else {
          defaultValue = .lossless
      }

      return Self[.appStorage(Names.pdfQuality.id), default: defaultValue]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var notSaveDocumentTagsAsPDFMetadata: Self {
        appStorage(Names.notSaveDocumentTagsAsPDFMetadata.id)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var notSaveDocumentTagsAsPDFMetadata: Self {
      @Dependency(\.defaultAppStorage) var store
      // try to fetch the value from a previous version
      let defaultValue = store.bool(forKey: "notSaveDocumentTagsAsPDFMetadata")
      return Self[.appStorage(Names.notSaveDocumentTagsAsPDFMetadata.id), default: defaultValue]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var documentTagsNotRequired: Self {
        appStorage(Names.documentTagsNotRequired.id)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var documentTagsNotRequired: Self {
      @Dependency(\.defaultAppStorage) var store
      // try to fetch the value from a previous version
      let defaultValue = store.bool(forKey: "documentTagsNotRequired")
      return Self[.appStorage(Names.documentTagsNotRequired.id), default: defaultValue]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var documentSpecificationNotRequired: Self {
        appStorage(Names.documentSpecificationNotRequired.id)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var documentSpecificationNotRequired: Self {
      @Dependency(\.defaultAppStorage) var store
      // try to fetch the value from a previous version
      let defaultValue = store.bool(forKey: "documentSpecificationNotRequired")
      return Self[.appStorage(Names.documentSpecificationNotRequired.id), default: defaultValue]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var appleIntelligenceEnabled: Self {
        appStorage(Names.appleIntelligenceEnabled.id)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var appleIntelligenceEnabled: Self {
      return Self[.appStorage(Names.appleIntelligenceEnabled.id), default: true]
  }
}

public extension SharedKey where Self == AppStorageKey<String?> {
    static var appleIntelligenceCustomPrompt: Self {
        appStorage(Names.appleIntelligenceCustomPrompt.id)
    }
}
public extension SharedKey where Self == AppStorageKey<String?>.Default {
  static var appleIntelligenceCustomPrompt: Self {
      return Self[.appStorage(Names.appleIntelligenceCustomPrompt.id), default: nil]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var appleIntelligenceCacheEnabled: Self {
        appStorage(Names.appleIntelligenceCacheEnabled.id)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var appleIntelligenceCacheEnabled: Self {
      return Self[.appStorage(Names.appleIntelligenceCacheEnabled.id), default: true]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var backgroundCacheNotificationsEnabled: Self {
        appStorage(Names.backgroundCacheNotificationsEnabled.id)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var backgroundCacheNotificationsEnabled: Self {
      return Self[.appStorage(Names.backgroundCacheNotificationsEnabled.id), default: false]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var multiTagSelectionDelayEnabled: Self {
        appStorage(Names.multiTagSelectionDelayEnabled.id)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var multiTagSelectionDelayEnabled: Self {
      return Self[.appStorage(Names.multiTagSelectionDelayEnabled.id), default: true]
  }

  static var ocrEnabled: Self {
      return Self[.appStorage(Names.ocrEnabled.id), default: false]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var highlightDetectedDateEnabled: Self {
        appStorage(Names.highlightDetectedDateEnabled.id)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var highlightDetectedDateEnabled: Self {
      return Self[.appStorage(Names.highlightDetectedDateEnabled.id), default: true]
  }
}

// MARK: global in memory storage

public extension SharedKey where Self == InMemoryKey<PremiumStatus> {
    static var premiumStatus: Self {
        inMemory("premiumStatus")
    }
}

public extension SharedKey where Self == InMemoryKey<Int?> {
    static var selectedDocumentId: Self {
        inMemory("selectedDocumentId")
    }
}

// MARK: file storage

public extension SharedKey where Self == FileStorageKey<IdentifiedArrayOf<Document>> {
  static var documents: Self {
      fileStorage(.temporaryDirectory.appending(component: "documents.json"))
  }
}

public extension SharedKey where Self == ArchivePathTypeCustomSharedKey {
  static var archivePathType: Self {
      @Dependency(\.defaultAppStorage) var store
      return ArchivePathTypeCustomSharedKey(key: "archivePathType", store: store)
  }
}

#if os(macOS)
public extension SharedKey where Self == ObservedFolderCustomSharedKey {
  static var observedFolder: Self {
      @Dependency(\.defaultAppStorage) var store
      return ObservedFolderCustomSharedKey(key: "observedFolderURL", store: store)
  }
}
#endif
