//
//  BackgroundProcessingActor.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 15.06.24.
//

import OSLog

protocol AsyncOperation: Sendable {
    func process() async
}

// https://forums.swift.org/t/how-do-i-properly-save-a-task-from-an-actors-initializer-and-why/63349
actor BackgroundProcessingActor<OperationType: AsyncOperation> {
    private let log = Logger(subsystem: "processing", category: "background-processing-actor")

    // this stream will be used to store incoming documents and images
    private let operationStream = AsyncStream<OperationType>.makeStream()

    private var processingTask: Task<Void, Never>?
    init() {}

    // we do not want to wait for the DocumentProcessingActor to be available to receive any new input, so we use nonisolated here add something to the queue
    nonisolated func queue(_ operation: OperationType) {
        log.debug("Receiving a new document")
        Task(priority: .userInitiated) {
            await self.add(operation)
        }
    }

    private func add(_ operation: OperationType) async {
        // the startupTask should be completed before running tasks
        if processingTask == nil {
            startProcessing()
        }
        operationStream.continuation.yield(operation)
    }

    private func startProcessing() {
        log.debug("Start processing")

        processingTask = Task(priority: .userInitiated) {
            self.log.debug("Start iterating over documents")
            // iterate over async stream and process documents
            for await operation in self.operationStream.stream {
                self.log.debug("Received a document in stream")
                await operation.process()
            }

            self.log.debug("Finished iterating over documents")
        }
    }
}
