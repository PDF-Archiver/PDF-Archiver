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
    func getMetadataTags() -> [String] {
        (documentAttributes?[PDFDocumentAttribute.keywordsAttribute] as? [String]) ?? []
    }

    func setMetadataTags(_ tags: [String]) {
        documentAttributes?[PDFDocumentAttribute.keywordsAttribute] = tags
    }

    func getContent(ofFirstPages lastPage: Int) -> String {
        var content = ""
        for index in 0...min(pageCount, lastPage) {
            guard let page = page(at: index),
                let pageContent = page.string else { continue }

            content.append(pageContent)
        }
        return content
    }
}
