//
//  NotificationCenter+Document.swift
//  
//
//  Created by Julian Kahnert on 10.02.21.
//

import Combine
import Foundation

extension Notification.Name {
    fileprivate static let editDocument = Notification.Name("editDocument")
}

extension NotificationCenter {
    public func edit(document: Document) {
        post(.init(name: .editDocument,
                   object: document))
    }

    public func editDocumentPublisher() -> AnyPublisher<Document, Never> {
        publisher(for: .editDocument)
            .compactMap { $0.object as? Document }
            .eraseToAnyPublisher()
    }
}
