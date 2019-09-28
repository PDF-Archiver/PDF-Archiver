//
//  Log.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 28.09.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
// swiftlint:disable force_unwrapping

import LoggingKit
import LogModel
import UIKit

enum Log {

    private static let shared = Logger(endpoint: Log.endpoint, shouldSend: Log.shouldSend)
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

    static func send(_ level: LoggerLevel, _ message: String, extra data: [String: String] = [:], file: String = #file, line: Int = #line, function: String = #function) {
        shared.send(level, message, extra: data, file: file, line: line, function: function)
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
