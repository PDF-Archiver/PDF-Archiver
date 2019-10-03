//
//  Log.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.09.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_unwrapping

import Keys
import Logging
import LoggingKit
import LogModel
import UIKit

enum Log {

    private static let shared = RestLogger(endpoint: Log.endpoint,
                                           username: PDFArchiverKeys().logUser,
                                           password: PDFArchiverKeys().logPassword,
                                           shouldSend: Log.shouldSend)
    private static let operationQueue = OperationQueue()
    private static let environment = AppEnvironment.get()
    private static let endpoint: URL = {
        if environment == .develop {
            return URL(string: "https://logs-develop.pdf-archiver.io/v1/addBatch")!
        }
        return URL(string: "https://logs.pdf-archiver.io/v1/addBatch")!
    }()
    private static let shouldSend: (() -> Bool) = {
        // return environment != .develop
        return true
    }

    static func send(_ level: Logger.Level, _ message: String, extra data: [String: String] = [:], file: String = #file, line: UInt = #line, function: String = #function) {
        let message = Logger.Message(stringLiteral: message)
        var metadata = Logger.Metadata()
        for (key, value) in data {
            metadata[key] = Logger.MetadataValue(stringLiteral: value)
        }
        shared.log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    static func sendOrPersistInBackground(_ application: UIApplication) {

        // source: https://developer.apple.com/videos/play/wwdc2019/707
        let operation = SendOperation()
        let identifier = application.beginBackgroundTask {
            operation.cancel()
        }
        operation.completionBlock = {
            application.endBackgroundTask(identifier)
        }
        operationQueue.addOperation(operation)
    }
}

extension Log {
    fileprivate class SendOperation: Operation {
        override func main() {
            Log.shared.sendOrPersist()
        }
    }
}
