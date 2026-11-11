//
//  SharedDefaults.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.05.25.
//

import Foundation

/// Not main-actor isolated: the widget's timeline providers read it from any thread, and
/// `UserDefaults` is thread-safe.
public enum SharedDefaults {
    // Computed, because a stored `UserDefaults` is not `Sendable`; instances of one suite share their storage.
    private static var sharedDefaults: UserDefaults {
        // swiftlint:disable:next force_unwrapping
        UserDefaults(suiteName: "group.PDFArchiverShared")!
    }

    public static func set(untaggedDocumentsCount count: Int) {
        sharedDefaults.set(count, forKey: "untaggedDocumentsCount")
        return
    }

    public static func getUntaggedDocumentsCount() -> Int {
        return sharedDefaults.integer(forKey: "untaggedDocumentsCount")
    }

    public typealias StatisticsType = [Int: Int]

    public static func set(statistics: StatisticsType) {
        do {
            let data = try JSONEncoder().encode(statistics)
            sharedDefaults.set(data, forKey: "widgetStatistics")
        } catch {
            assertionFailure("Failed to encode statistics")
        }
    }

    public static func getStatistics() -> StatisticsType {
        guard let data = sharedDefaults.object(forKey: "widgetStatistics") as? Data else {
            return [:]
        }
        do {
            return try JSONDecoder().decode(StatisticsType.self, from: data)
        } catch {
            assertionFailure("Failed to decode statistics")
            return [:]
        }
    }
}
