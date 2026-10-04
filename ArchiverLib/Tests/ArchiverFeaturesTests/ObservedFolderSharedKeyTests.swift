//
//  ObservedFolderSharedKeyTests.swift
//  ArchiverLib
//

#if os(macOS)
import ComposableArchitecture
import Dependencies
import Foundation
import Shared
import Testing

struct ObservedFolderSharedKeyTests {
    private let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// Saving the folder writes the bookmark and KVO fires in-process; answering that
    /// notification with the initial value threw the folder away while its bookmark stayed on disk.
    @Test
    func picksUpABookmarkWrittenStraightToTheStore() throws {
        let store = UserDefaults.inMemory
        try withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            @SharedReader(.observedFolder) var observedFolder: URL?
            let bookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            store.set(bookmark, forKey: "observedFolderURL")

            #expect(observedFolder.map(Self.canonicalPath) == Self.canonicalPath(folder))
        }
    }

    /// A drive that is not mounted at launch fails to resolve once; the stored bookmark has to
    /// survive that, or the location is lost for good.
    @Test
    func aBookmarkThatFailsToResolveStaysStored() {
        let store = UserDefaults.inMemory
        let unresolvable = Data("not a bookmark".utf8)
        store.set(unresolvable, forKey: "observedFolderURL")

        withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            @SharedReader(.observedFolder) var observedFolder: URL?

            #expect(observedFolder == nil)
            #expect(store.object(forKey: "observedFolderURL") as? Data == unresolvable)
        }
    }

    /// A resolved bookmark comes back canonical (`/private/var/…`), the test's folder does not.
    private static func canonicalPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
#endif
