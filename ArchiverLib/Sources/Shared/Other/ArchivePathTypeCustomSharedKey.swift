//
//  ArchivePathTypeCustomSharedKey.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 11.09.25.
//

import ArchiverModels
import ComposableArchitecture
import Foundation

public struct ArchivePathTypeCustomSharedKey: SharedKey, Log {
    private let key: String
    private let store: UncheckedSendable<UserDefaults>

    init(key: String, store: UserDefaults) {
        self.key = key
        self.store = UncheckedSendable(store)
    }

    public func load(context: LoadContext<StorageType?>, continuation: LoadContinuation<StorageType?>) {
        let value = getArchivePathType(from: store.wrappedValue)

        continuation.resume(with: .success(value))
    }

    public func subscribe(context: LoadContext<StorageType?>, subscriber: SharedSubscriber<StorageType?>) -> SharedSubscription {

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

    public func save(_ value: StorageType?, context: SaveContext, continuation: SaveContinuation) {
        setArchivePathType(value: value, in: store.wrappedValue)
        continuation.resume()
    }

    private func getArchivePathType(from store: UserDefaults) -> StorageType? {
        do {
            var staleBookmarkData = false
            if let type: StorageType? = try? store.getObject(forKey: key) {
                return type
            } else if let bookmarkData = store.object(forKey: key) as? Data {
#if os(macOS)
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
                if staleBookmarkData {
                    store.set(nil, forKey: key)
                    log.errorAndAssert("Found stale bookmark data.")
                    return nil
                }
                return .local(url)
#else
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &staleBookmarkData)
                guard !staleBookmarkData else {
                    // Handle stale data here.
                    log.errorAndAssert("Error while getting archive url. Stale bookmark data.")
                    return nil
                }
                return .local(url)
#endif
            } else {
                return nil
            }
        } catch {
            store.set(nil, forKey: key)
            log.errorAndAssert("Error while getting archive url.", metadata: ["error": "\(String(describing: error))"])
            return nil
        }
    }

    private func setArchivePathType(value newValue: StorageType?, in store: UserDefaults) {
        do {
            switch newValue {
            case .local(let url):
                #if os(macOS)
                let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                store.set(bookmark, forKey: key)
                #else
                // Securely access the URL to save a bookmark
                guard url.startAccessingSecurityScopedResource() else {
                    // Handle the failure here.
                    return
                }
                // We have to stop accessing the resource no matter what
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    // Make sure the bookmark is minimal!
                    let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                    store.set(bookmark, forKey: key)
                } catch {
                    log.errorAndAssert("Bookmark error \(error)")
                }
                #endif
            default:
                try store.setObject(newValue, forKey: key)
            }
        } catch {
            store.set(nil, forKey: key)
            log.errorAndAssert("Failed to set ArchivePathType.", metadata: ["error": "\(error)"])
        }
    }

    private final class Observer: NSObject, Sendable {
      let didChange: @Sendable () -> Void
      init(didChange: @escaping @Sendable () -> Void) {
        self.didChange = didChange
        super.init()
      }
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

extension ArchivePathTypeCustomSharedKey {
    public struct ArchivePathTypeCustomaredKeyId: Hashable {
      fileprivate let key: String
      fileprivate let store: UserDefaults
    }

    public var id: ArchivePathTypeCustomaredKeyId {
        ArchivePathTypeCustomaredKeyId(key: key, store: store.wrappedValue)
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
