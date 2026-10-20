//
//  DistinctFetchKey.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 01.10.26.
//

import Dependencies
import GRDB
import Sharing
import SQLiteData
import Synchronization

/// Observes a request like `@Fetch`, but publishes a result only when it differs from the last one.
///
/// sqlite-data's own key yields every refetch and Sharing notifies on every yield, so each commit
/// to an observed table re-renders its views, even when the reconcile or the text index wrote
/// nothing a view shows.
public struct DistinctFetchKey<Value: Equatable & Sendable>: SharedReaderKey {
    let database: any DatabaseReader
    let request: any FetchKeyRequest<Value>
#if DEBUG
    let isDefaultDatabase: Bool
#endif

    public struct ID: Hashable {
        let databaseID: ObjectIdentifier
        let request: AnyHashable
    }

    public var id: ID {
        ID(databaseID: ObjectIdentifier(database), request: AnyHashable(request))
    }

    init(request: some FetchKeyRequest<Value>) {
        @Dependency(\.defaultDatabase) var database
        self.database = database
        self.request = request
#if DEBUG
        // sqlite-data's `defaultDatabaseLabel` is `package`, so its value is repeated here.
        self.isDefaultDatabase = database.configuration.label == "co.pointfree.SQLiteData.testValue"
#endif
    }

    public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
#if DEBUG
        // An unconfigured default database (previews) has none of the tables.
        guard !isDefaultDatabase else {
            continuation.resumeReturningInitialValue()
            return
        }
#endif
        // The initial value arrives synchronously from the subscription's first fetch.
        guard case .userInitiated = context else {
            continuation.resumeReturningInitialValue()
            return
        }
        database.asyncRead { [request] dbResult in
            continuation.resume(with: dbResult.flatMap { db in Result { try request.fetch(db) } })
        }
    }

    public func subscribe(context: LoadContext<Value>, subscriber: SharedSubscriber<Value>) -> SharedSubscription {
#if DEBUG
        guard !isDefaultDatabase else {
            return SharedSubscription {}
        }
#endif
        // A `Result`, so one failed fetch does not end the observation.
        let observation = ValueObservation
            .tracking { [request] db in Result { try request.fetch(db) } }
            .removeDuplicates { lhs, rhs in
                guard case .success(let lhs) = lhs, case .success(let rhs) = rhs else { return false }
                return lhs == rhs
            }

        // After `load(_:)` the reference already holds the first fetch.
        let skipsNext: Mutex<Bool>
        switch context {
        case .initialValue:
            skipsNext = Mutex(false)

        case .userInitiated:
            skipsNext = Mutex(true)
        }
        let cancellable = observation.start(in: database, scheduling: ImmediateScheduler()) { error in
            subscriber.yield(throwing: error)
        } onChange: { result in
            let skip = skipsNext.withLock { value in
                defer { value = false }
                return value
            }
            guard !skip else { return }
            subscriber.yield(with: result.map(Optional.some))
        }
        return SharedSubscription {
            cancellable.cancel()
        }
    }
}

extension SharedReaderKey {
    public static func distinctFetch<Value>(_ request: some FetchKeyRequest<Value>) -> Self
    where Self == DistinctFetchKey<Value> {
        DistinctFetchKey(request: request)
    }

    public static func distinctFetch<Records: RangeReplaceableCollection>(_ request: some FetchKeyRequest<Records>) -> Self
    where Self == DistinctFetchKey<Records>.Default {
        Self[.distinctFetch(request), default: Records()]
    }
}

/// Every row a statement selects, as a request for `distinctFetch(_:)`.
public struct FetchAllRequest<Row: QueryRepresentable>: FetchKeyRequest where Row.QueryOutput: Sendable {
    let query: QueryFragment

    public init(_ statement: some StructuredQueriesCore.Statement<Row>) {
        self.query = statement.query
    }

    public func fetch(_ db: Database) throws -> [Row.QueryOutput] {
        try SQLQueryExpression(query, as: Row.self).fetchAll(db)
    }
}

/// Delivers on the database's own queue, like sqlite-data's key: GRDB's `.immediate` traps
/// unless it is started on the main thread.
private struct ImmediateScheduler: ValueObservationScheduler {
    func immediateInitialValue() -> Bool { true }

    func schedule(_ action: @escaping @Sendable () -> Void) {
        action()
    }
}
