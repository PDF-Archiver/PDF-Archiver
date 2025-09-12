// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArchiverLib",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ArchiverLib",
            targets: ["ArchiverFeatures", "ArchiverIntents"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.22.0"),
        .package(url: "https://github.com/sideeffect-io/AsyncExtensions", from: "0.5.4"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.4")
    ],
    targets: [
        .target(name: "ArchiverFeatures",
                dependencies: [
                    "ArchiverDocumentProcessing",
                    "ArchiverStore",
                    "ArchiverModels",
                    "ArchiverIntents",
                    "Shared",
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
                ],
                resources: [
                    .process("Localizable.xcstrings")
                ],
                swiftSettings: [
                    .enableExperimentalFeature("StrictConcurrency")
                    // These features can currently not be enabled, see:
                    // https://github.com/pointfreeco/swift-dependencies/discussions/267
//                    .defaultIsolation(MainActor.self),
//                    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
//                    .enableUpcomingFeature("InferIsolatedConformances")
                ]),
        .target(name: "ArchiverStore",
                dependencies: [
                    "ArchiverModels",
                    "Shared",
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    "AsyncExtensions",
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
                ],
                swiftSettings: [
                    .enableExperimentalFeature("StrictConcurrency"),
                    .defaultIsolation(MainActor.self),
                    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                    .enableUpcomingFeature("InferIsolatedConformances")
                ]),
        .target(name: "ArchiverIntents",
                dependencies: [
                    "Shared"
                ],
                swiftSettings: [
                    .enableExperimentalFeature("StrictConcurrency"),
                    .defaultIsolation(MainActor.self),
                    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                    .enableUpcomingFeature("InferIsolatedConformances")
                ]),
        .target(name: "ArchiverModels",
                dependencies: [],
                swiftSettings: [
                    .enableExperimentalFeature("StrictConcurrency"),
                    .defaultIsolation(MainActor.self),
                    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                    .enableUpcomingFeature("InferIsolatedConformances")
                ]),
        .target(name: "ArchiverDocumentProcessing",
                dependencies: ["Shared"],
                swiftSettings: [
                    .enableExperimentalFeature("StrictConcurrency"),
                    .defaultIsolation(MainActor.self),
                    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                    .enableUpcomingFeature("InferIsolatedConformances")
                ]),
        .target(name: "Shared",
                dependencies: [
                    "ArchiverModels",
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
                ],
                swiftSettings: [
                    .enableExperimentalFeature("StrictConcurrency"),
                    .defaultIsolation(MainActor.self),
                    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                    .enableUpcomingFeature("InferIsolatedConformances")
                ]),
        .testTarget(
            name: "ArchiverFeaturesTests",
            dependencies: ["ArchiverFeatures"]
        ),
        .testTarget(
            name: "ArchiverStoreTests",
            dependencies: ["ArchiverStore"]
        ),
        .testTarget(
            name: "ArchiverDocumentProcessingTests",
            dependencies: ["ArchiverDocumentProcessing"],
            resources: [
                .process("assets")
            ]
        )
    ]
)
