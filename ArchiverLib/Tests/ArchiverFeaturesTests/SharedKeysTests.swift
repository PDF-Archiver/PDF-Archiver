//
//  SharedKeysTests.swift
//  ArchiverLib
//
//  Regression tests for the app storage isolation of the shared keys.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import ArchiverFeatures

@Suite("SharedKeys app storage isolation")
struct SharedKeysTests {

    @Test("A value written in one dependency scope does not leak into another")
    func appStorageIsIsolatedBetweenScopes() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            @Shared(.appleIntelligenceEnabled) var appleIntelligenceEnabled
            $appleIntelligenceEnabled.withLock { $0 = false }
            #expect(appleIntelligenceEnabled == false)
        }

        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            @Shared(.appleIntelligenceEnabled) var appleIntelligenceEnabled
            #expect(appleIntelligenceEnabled == true)
        }
    }

    @Test("The legacy migration default reads the injected store")
    func legacyMigrationUsesTheInjectedStore() {
        let storeWithLegacyValue = UserDefaults.inMemory
        storeWithLegacyValue.set(true, forKey: "documentTagsNotRequired")

        withDependencies {
            $0.defaultAppStorage = storeWithLegacyValue
        } operation: {
            @Shared(.documentTagsNotRequired) var documentTagsNotRequired
            #expect(documentTagsNotRequired == true)
        }

        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            @Shared(.documentTagsNotRequired) var documentTagsNotRequired
            #expect(documentTagsNotRequired == false)
        }
    }
}
