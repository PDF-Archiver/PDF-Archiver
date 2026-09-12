//
//  ProcessingEvent.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 07.07.26.
//

import Foundation

/// Progress events emitted by ``DocumentProcessor`` while import requests move
/// through its queue.
///
/// `source` is the staged file that represents the request (for multi-page
/// scans: the first page image).
public enum ProcessingEvent: Sendable, Equatable {
    case queued(source: URL)
    case processing(source: URL)
    case finished(source: URL, document: URL)
    case failed(source: URL, message: String)
}
