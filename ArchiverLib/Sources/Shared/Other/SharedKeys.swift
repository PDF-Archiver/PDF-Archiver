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

    var id: String { "shared-\(rawValue)" }
}

// MARK: user defaults

/// `true` if the tutorial was already shown
public extension SharedKey where Self == AppStorageKey<Bool> {
  static var tutorialShown: Self {
      appStorage(Names.tutorialShown.id, store: .standard)
  }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var tutorialShown: Self {
      let defaultValue = (UserDefaults.standard.value(forKey: "tutorial-v1") as? Bool) ?? false
      return Self[.appStorage(Names.tutorialShown.id, store: .standard), default: defaultValue]
  }
}

/// Default quality of a the images that will be processed to a PDF document
public extension SharedKey where Self == AppStorageKey<Float> {
    static var pdfQuality: Self {
        appStorage(Names.pdfQuality.id, store: .standard)
    }
}
public extension SharedKey where Self == AppStorageKey<PDFQuality>.Default {
  static var pdfQuality: Self {
      let defaultValue: PDFQuality

      // try to fetch the value from a previous version
      if let oldValue = UserDefaults.standard.value(forKey: "pdfQuality") as? Float,
         oldValue != 0,
        let oldPdfQuality = PDFQuality(rawValue: oldValue) {
          defaultValue = oldPdfQuality
      } else {
          defaultValue = .lossless
      }

      return Self[.appStorage(Names.pdfQuality.id, store: .standard), default: defaultValue]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var notSaveDocumentTagsAsPDFMetadata: Self {
        appStorage(Names.notSaveDocumentTagsAsPDFMetadata.id, store: .standard)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var notSaveDocumentTagsAsPDFMetadata: Self {
      let defaultValue = UserDefaults.standard.bool(forKey: "notSaveDocumentTagsAsPDFMetadata")
      return Self[.appStorage(Names.notSaveDocumentTagsAsPDFMetadata.id, store: .standard), default: defaultValue]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var documentTagsNotRequired: Self {
        appStorage(Names.documentTagsNotRequired.id, store: .standard)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var documentTagsNotRequired: Self {
      let defaultValue = UserDefaults.standard.bool(forKey: "documentTagsNotRequired")
      return Self[.appStorage(Names.documentTagsNotRequired.id, store: .standard), default: defaultValue]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var documentSpecificationNotRequired: Self {
        appStorage(Names.documentSpecificationNotRequired.id, store: .standard)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var documentSpecificationNotRequired: Self {
      let defaultValue = UserDefaults.standard.bool(forKey: "documentSpecificationNotRequired")
      return Self[.appStorage(Names.documentSpecificationNotRequired.id, store: .standard), default: defaultValue]
  }
}

public extension SharedKey where Self == AppStorageKey<Bool> {
    static var appleIntelligenceEnabled: Self {
        appStorage(Names.appleIntelligenceEnabled.id, store: .standard)
    }
}
public extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var appleIntelligenceEnabled: Self {
      let defaultValue = (UserDefaults.standard.value(forKey: "appleIntelligenceEnabled") as? Bool) ?? false
      return Self[.appStorage(Names.appleIntelligenceEnabled.id, store: .standard), default: defaultValue]
  }
}

public extension SharedKey where Self == AppStorageKey<String?> {
    static var appleIntelligenceCustomPrompt: Self {
        appStorage(Names.appleIntelligenceCustomPrompt.id, store: .standard)
    }
}
public extension SharedKey where Self == AppStorageKey<String?>.Default {
  static var appleIntelligenceCustomPrompt: Self {
      return Self[.appStorage(Names.appleIntelligenceCustomPrompt.id, store: .standard), default: nil]
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
      ArchivePathTypeCustomSharedKey(key: "archivePathType", store: .standard)
  }
}

#if os(macOS)
public extension SharedKey where Self == ObservedFolderCustomSharedKey {
  static var observedFolder: Self {
      ObservedFolderCustomSharedKey(key: "observedFolderURL", store: .standard)
  }
}
#endif
