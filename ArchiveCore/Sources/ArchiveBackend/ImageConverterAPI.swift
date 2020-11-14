//
//  ImageConverterAPI.swift
//  
//
//  Created by Julian Kahnert on 11.10.20.
//

import Foundation

public protocol ImageConverterAPI: class {
    var totalDocumentCount: Atomic<Int> { get }

    func handle(_ url: URL) throws
    func startProcessing() throws
    func stopProcessing()
    func getOperationCount() -> Int
}
