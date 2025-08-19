// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArchiverLib",
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
                ]),
        .target(name: "ArchiverStore",
                dependencies: [
                    "ArchiverModels",
                    "Shared",
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    "AsyncExtensions",
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
                ]),
        .target(name: "ArchiverIntents",
                dependencies: [
                    "Shared"
                ]),
//                swiftSettings: [.defaultIsolaion(MainActor.self)]),
        .target(name: "ArchiverModels",
                dependencies: []),
        .target(name: "ArchiverDocumentProcessing",
                dependencies: ["Shared"]),
        .target(name: "Shared",
                dependencies: [
                    "ArchiverModels",
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
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
