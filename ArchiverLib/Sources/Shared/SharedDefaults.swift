//
//  SharedDefaults.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 29.05.25.
//

import Foundation

@MainActor
public enum SharedDefaults {
    private static let sharedDefaults = UserDefaults(suiteName: "group.PDFArchiverShared")!

    public static func set(untaggedDocumentsCount count: Int) {
        return sharedDefaults.set(count, forKey: "untaggedDocumentsCount")
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
        guard let data = sharedDefaults.object(forKey: "widgetStatistics") as? Data else { return [:] }
        do {
            return try JSONDecoder().decode(StatisticsType.self, from: data)
        } catch {
            assertionFailure("Failed to decode statistics")
            return [:]
        }
    }
}
