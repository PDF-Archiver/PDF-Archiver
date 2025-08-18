import Foundation
import OSLog
import Shared

extension UserDefaults: Log {
    static var appGroup: UserDefaults {
        // swiftlint:disable:next force_unwrapping
//        UserDefaults(suiteName: Constants.sharedContainerIdentifier)!
        UserDefaults.standard
    }

    enum Names: String, CaseIterable {
//        case tutorialShown = "tutorial-v1"
//        case isTaggingMode
//        case pdfQuality
//        case lastAppUsagePermitted
//        case archiveURL
//        case untaggedURL
        case observedFolderURL
        case archivePathType
//        case notSaveDocumentTagsAsPDFMetadata
//        case documentTagsNotRequired
//        case documentSpecificationNotRequired
    }

    static var isInDemoMode: Bool {
        UserDefaults.standard.bool(forKey: "demoMode")
    }

    #if os(macOS)
    static var observedFolderURL: URL? {
        get {
            guard let bookmarkData = appGroup.object(forKey: Names.observedFolderURL.rawValue) as? Data else { return nil }

            do {
                var staleBookmarkData = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
                if staleBookmarkData {
                    appGroup.set(nil, forKey: Names.observedFolderURL.rawValue)
                    log.errorAndAssert("Found stale bookmark data.")
                    return nil
                }
                return url
            } catch {
                appGroup.set(nil, forKey: Names.observedFolderURL.rawValue)
                log.errorAndAssert("Failed to get observedFolderURL", metadata: ["error": "\(error)"])
                NotificationCenter.default.postAlert(error)
                return nil
            }
        }
        set {
            do {
                if let url = newValue {
                    let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    appGroup.set(bookmark, forKey: Names.observedFolderURL.rawValue)
                } else {
                    appGroup.set(nil, forKey: Names.observedFolderURL.rawValue)
                }
            } catch {
                appGroup.set(nil, forKey: Names.observedFolderURL.rawValue)
                log.errorAndAssert("Failed to set observedFolderURL.", metadata: ["error": "\(error)"])
                NotificationCenter.default.postAlert(error)
            }
        }
    }
    #endif

    static var archivePathType: PathManager.ArchivePathType? {
        get {

            do {
                var staleBookmarkData = false
                if let type: PathManager.ArchivePathType = try? appGroup.getObject(forKey: .archivePathType) {
                    return type
                } else if let bookmarkData = appGroup.object(forKey: Names.archivePathType.rawValue) as? Data {
                    #if os(macOS)
                    let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &staleBookmarkData)
                    if staleBookmarkData {
                        appGroup.set(nil, forKey: Names.archivePathType.rawValue)
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
                appGroup.set(nil, forKey: Names.archivePathType.rawValue)
                log.errorAndAssert("Error while getting archive url.", metadata: ["error": "\(String(describing: error))"])
                return nil
            }
        }
        set {
            do {
                switch newValue {
                case .local(let url):
                    #if os(macOS)
                    let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    appGroup.set(bookmark, forKey: Names.archivePathType.rawValue)
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
                        appGroup.set(bookmark, forKey: Names.archivePathType.rawValue)
                    } catch {
                        Logger.settings.errorAndAssert("Bookmark error \(error)")
                    }
                    #endif
                default:
                    try appGroup.setObject(newValue, forKey: .archivePathType)
                }
            } catch {
                appGroup.set(nil, forKey: Names.archivePathType.rawValue)
                log.errorAndAssert("Failed to set ArchivePathType.", metadata: ["error": "\(error)"])
            }
        }
    }

    private func setObject<T: Encodable>(_ object: T?, forKey key: Names) throws {
        guard let object = object else {
            set(nil, forKey: key.rawValue)
            return
        }
        let data = try JSONEncoder().encode(object)
        set(data, forKey: key.rawValue)
    }

    private func getObject<T: Decodable>(forKey key: Names) throws -> T? {
        guard let data = object(forKey: key.rawValue) as? Data else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
