//
//  async-await-migration.swift
//  iOS
//
//  Created by Julian Kahnert on 19.03.24.
//

import Foundation

// https://forums.swift.org/t/using-async-functions-from-synchronous-functions-and-breaking-all-the-rules/59782/4
fileprivate class Box<ResultType> {
    var result: Result<ResultType, Error>? = nil
}

/// Unsafely awaits an async function from a synchronous context.
@available(*, deprecated, message: "Migrate to structured concurrency")
func _unsafeWait<ResultType>(_ f: @escaping () async throws -> ResultType) throws -> ResultType {
    let box = Box<ResultType>()
    let sema = DispatchSemaphore(value: 0)
    Task {
        do {
            let val = try await f()
            box.result = .success(val)
        } catch {
            box.result = .failure(error)
        }
        sema.signal()
    }
    sema.wait()
    return try box.result!.get()
}
