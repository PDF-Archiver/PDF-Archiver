//
//  BookmarkSharedKey.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 11.09.25.
//

import ArchiverModels
import ComposableArchitecture
import Foundation
import Logging

/// A `UserDefaults` key whose value is kept as a security-scoped bookmark and resolved on every read.
///
/// A read never writes to the store: a bookmark that does not resolve right now (an unmounted
/// drive, a folder that is gone for the moment) keeps its data, so the location is back once
/// the volume is.
nonisolated public struct BookmarkSharedKey<Value: Sendable>: SharedKey {
    private let key: String
    private let store: UncheckedSendable<UserDefaults>
    private let read: @Sendable (UserDefaults, String) -> Value
    private let write: @Sendable (Value, UserDefaults, String) -> Void

    init(key: String,
         store: UserDefaults,
         read: @escaping @Sendable (UserDefaults, String) -> Value,
         write: @escaping @Sendable (Value, UserDefaults, String) -> Void) {
        // KVO reads the key as a key path.
        assert(!key.contains("."))
        assert(!key.hasPrefix("@"))
        self.key = key
        self.store = UncheckedSendable(store)
        self.read = read
        self.write = write
    }

    public func load(context: LoadContext<Value>, continuation: LoadContinuation<Value>) {
        continuation.resume(with: .success(read(store.wrappedValue, key)))
    }

    public func subscribe(context: LoadContext<Value>, subscriber: SharedSubscriber<Value>) -> SharedSubscription {
        let observer = Observer {
            subscriber.yield(with: .success(read(store.wrappedValue, key)))
        }
        store.wrappedValue.addObserver(observer, forKeyPath: key, context: nil)
        return SharedSubscription { store.wrappedValue.removeObserver(observer, forKeyPath: key) }
    }

    public func save(_ value: Value, context: SaveContext, continuation: SaveContinuation) {
        write(value, store.wrappedValue, key)
        continuation.resume()
    }

    public struct ID: Hashable {
        fileprivate let key: String
        fileprivate let store: UserDefaults
    }

    public var id: ID {
        ID(key: key, store: store.wrappedValue)
    }

    private final class Observer: NSObject, Sendable {
        let didChange: @Sendable () -> Void
        init(didChange: @escaping @Sendable () -> Void) {
            self.didChange = didChange
            super.init()
        }

        // swiftlint:disable:next block_based_kvo
        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            self.didChange()
        }
    }
}

extension BookmarkSharedKey where Value == URL? {
    /// A folder the user picked, stored as its bookmark.
    static func folder(key: String, store: UserDefaults) -> Self {
        Self(key: key, store: store) { store, key in
            (store.object(forKey: key) as? Data).flatMap(SecurityScopedBookmark.resolve)
        } write: { url, store, key in
            if let url {
                SecurityScopedBookmark.store(url, in: store, forKey: key)
            } else {
                store.set(nil, forKey: key)
            }
        }
    }
}

extension BookmarkSharedKey where Value == StorageType? {
    /// `.local` is stored as the folder's bookmark, every other case as JSON.
    static func archivePathType(key: String, store: UserDefaults) -> Self {
        Self(key: key, store: store) { store, key in
            guard let data = store.object(forKey: key) as? Data else { return nil }
            if let type = try? JSONDecoder().decode(StorageType.self, from: data) {
                return type
            }
            return SecurityScopedBookmark.resolve(data).map(StorageType.local)
        } write: { type, store, key in
            switch type {
            case .local(let url):
                SecurityScopedBookmark.store(url, in: store, forKey: key)

            case .some(let type):
                do {
                    store.set(try JSONEncoder().encode(type), forKey: key)
                } catch {
                    SecurityScopedBookmark.log.error("Failed to encode storage type", metadata: ["error": "\(LogRedact.describe(error))"])
                }

            case nil:
                store.set(nil, forKey: key)
            }
        }
    }
}

/// The bookmark of a folder the user picked, which lets the app reach it again after a relaunch.
nonisolated enum SecurityScopedBookmark: Log {
    static func resolve(_ data: Data) -> URL? {
        do {
            var isStale = false
            #if os(macOS)
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            #else
            let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
            #endif
            // A stale bookmark still resolves; the next save of the folder refreshes it.
            if isStale {
                log.notice("Resolved a stale bookmark")
            }
            return url
        } catch {
            log.error("Failed to resolve bookmark", metadata: ["error": "\(LogRedact.describe(error))"])
            NotificationCenter.default.postAlert(error)
            return nil
        }
    }

    /// Keeps the stored bookmark when the new one cannot be made: the folder picked last is
    /// better than none.
    static func store(_ url: URL, in store: UserDefaults, forKey key: String) {
        do {
            store.set(try make(for: url), forKey: key)
        } catch {
            log.error("Failed to create bookmark", metadata: ["error": "\(LogRedact.describe(error))"])
            NotificationCenter.default.postAlert(error)
        }
    }

    private static func make(for url: URL) throws -> Data {
        #if os(macOS)
        return try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        // The document picker hands the folder out security scoped; a minimal bookmark is all iOS keeps.
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        #endif
    }
}
