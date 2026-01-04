//
//  ArchivePathTypeCustomSharedKey.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 11.09.25.
//

import ComposableArchitecture
import Foundation

@available(iOS, unavailable)
nonisolated public struct ObservedFolderCustomSharedKey: SharedKey, Log {
    private let key: String
    private let store: UncheckedSendable<UserDefaults>

    init(key: String, store: UserDefaults) {
        self.key = key
        self.store = UncheckedSendable(store)
    }

    public func load(context: LoadContext<URL?>, continuation: LoadContinuation<URL?>) {
        let value = getObservedFolder(from: store.wrappedValue)

        continuation.resume(with: .success(value))
    }

    public func subscribe(context: LoadContext<URL?>, subscriber: SharedSubscriber<URL?>) -> SharedSubscription {

        assert(!key.contains("."))
        assert(!key.hasPrefix("@"))

        let observer = Observer {
            subscriber.yield(with: .success(context.initialValue))
        }
        store.wrappedValue.addObserver(observer, forKeyPath: key, context: nil)

        let removeObserver: @Sendable () -> Void
        removeObserver = { store.wrappedValue.removeObserver(observer, forKeyPath: key) }

        return SharedSubscription(removeObserver)
    }

    public func save(_ value: URL?, context: SaveContext, continuation: SaveContinuation) {
        setObservedFolder(value: value, in: store.wrappedValue)
        continuation.resume()
    }

    private func getObservedFolder(from store: UserDefaults) -> URL? {
        guard let bookmarkData = store.object(forKey: key) as? Data else { return nil }

        do {
            var staleBookmarkData = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
            if staleBookmarkData {
                store.set(nil, forKey: key)
                log.errorAndAssert("Found stale bookmark data.")
                return nil
            }
            return url
        } catch {
            store.set(nil, forKey: key)
            log.errorAndAssert("Failed to get observedFolderURL", metadata: ["error": "\(error)"])
            Task {
                await NotificationCenter.default.postAlert(error)
            }
            return nil
        }
    }

    private func setObservedFolder(value newValue: URL?, in store: UserDefaults) {
        do {
            if let url = newValue {
                let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                store.set(bookmark, forKey: key)
            } else {
                store.set(nil, forKey: key)
            }
        } catch {
            store.set(nil, forKey: key)
            log.errorAndAssert("Failed to set observedFolderURL.", metadata: ["error": "\(error)"])
            Task {
                await NotificationCenter.default.postAlert(error)
            }
        }
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

@available(iOS, unavailable)
extension ObservedFolderCustomSharedKey {
    nonisolated public struct ObservedFolderCustomSharedKeyId: Hashable {
      fileprivate let key: String
      fileprivate let store: UserDefaults
    }

    public var id: ObservedFolderCustomSharedKeyId {
        ObservedFolderCustomSharedKeyId(key: key, store: store.wrappedValue)
    }
}

fileprivate extension UserDefaults {
    func setObject<T: Encodable>(_ object: T?, forKey key: String) throws {
        guard let object = object else {
            set(nil, forKey: key)
            return
        }
        let data = try JSONEncoder().encode(object)
        set(data, forKey: key)
    }

    func getObject<T: Decodable>(forKey key: String) throws -> T? {
        guard let data = object(forKey: key) as? Data else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
