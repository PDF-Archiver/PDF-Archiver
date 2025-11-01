//
//  AppleIntelligenceAvailability.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 15.10.25.
//

public enum AppleIntelligenceAvailability: String, Sendable, Equatable {
    case available
    case unavailable
    case deviceNotCompatible
    case operatingSystemNotCompatible // iOS < 26 or macOS < 26

    nonisolated public var isUsable: Bool {
        self == .available
    }
}
