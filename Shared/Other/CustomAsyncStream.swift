//
//  CustomAsyncStream.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 18.10.24.
//

struct CustomAsyncStream<Value: Sendable>: AsyncSequence, AsyncIteratorProtocol {
    typealias AsyncIterator = CustomAsyncStream
    
    typealias Element = Value
    
    private(set) var operationStream: AsyncStream<Value>!
    private var continuation: AsyncStream<Value>.Continuation!
    
    private init() {}
    
    func next() async throws -> Value? {
        var tmp = operationStream.makeAsyncIterator()
        return await tmp.next()
    }
    
    func makeAsyncIterator() -> CustomAsyncStream {
        self
    }
    
    static func create() -> Self {
        var customstream = Self()
        customstream.operationStream = AsyncStream { (continuation: AsyncStream<Value>.Continuation) -> Void in
            customstream.continuation = continuation
        }
        return customstream
    }
    
    func send(_ value: Value) {
        continuation.yield(value)
    }
}
