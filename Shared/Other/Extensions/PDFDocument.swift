//
//  PDFDocument.swift
//  
//
//  Created by Julian Kahnert on 25.02.21.
//

#if os(macOS)
import Quartz.PDFKit
#else
import PDFKit
#endif

extension PDFDocument {
    public func getMetadataTags() -> [String] {
        (documentAttributes?[PDFDocumentAttribute.keywordsAttribute] as? [String]) ?? []
    }

    public func setMetadataTags(_ tags: [String]) {
        documentAttributes?[PDFDocumentAttribute.keywordsAttribute] = tags
    }
}
