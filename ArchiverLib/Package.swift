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
            targets: ["ArchiverFeatures", "ArchiverIntents"]),
        .library(
            name: "Shared",
            targets: ["Shared"]),
        .library(
            name: "DocumentProcessingPipeline",
            targets: ["DocumentProcessingPipeline"]),
        .library(
            name: "EvaluationSupport",
            targets: ["ArchiverModels", "ContentExtractorStore", "EvaluationCorpus"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture",
                 exact: "1.26.2",
                 traits: [
                    "ComposableArchitecture2Deprecations",
                    "ComposableArchitecture2DeprecationOverloads"
                 ]),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", exact: "1.17.1"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", exact: "2.10.1"),
        .package(url: "https://github.com/sideeffect-io/AsyncExtensions", exact: "0.5.5"),
        .package(url: "https://github.com/apple/swift-async-algorithms", exact: "1.1.5")
    ],
    targets: [
        .target(name: "ArchiverFeatures",
                dependencies: [
                    "ArchiverModels",
                    "ArchiverIntents",
                    "ArchiverStore",
                    "ContentExtractorStore",
                    "DocumentProcessingPipeline",
                    "Shared",
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
                ],
                resources: [
                    .process("Localizable.xcstrings")
                ]),
        .target(name: "ArchiverStore",
                dependencies: [
                    "ArchiverModels",
                    "Shared",
                    .product(name: "Dependencies", package: "swift-dependencies"),
                    .product(name: "DependenciesMacros", package: "swift-dependencies"),
                    .product(name: "Sharing", package: "swift-sharing"),
                    "AsyncExtensions",
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
                ]),
        .target(name: "ArchiverIntents",
                dependencies: [
                    "ArchiverModels",
                    "Shared"
                ],
                resources: [
                    .process("Localizable.xcstrings")
                ]),
        .target(name: "ArchiverModels",
                dependencies: []),
        .target(name: "ContentExtractorStore",
                dependencies: [
                    "ArchiverModels"
                ]),
        .target(name: "DocumentProcessingPipeline",
                dependencies: [
                    "ArchiverModels",
                    "ContentExtractorStore"
                ]),
        .target(name: "EvaluationCorpus",
                dependencies: [
                    "ArchiverModels",
                    "ContentExtractorStore"
                ]),
        .executableTarget(name: "EvalCorpusBuilder",
                          dependencies: [
                            "EvaluationCorpus"
                          ]),
        .target(name: "Shared",
                dependencies: [
                    "ArchiverModels",
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
                ],
                resources: [
                    .process("Resources/Localizable.xcstrings"),
                    .process("Resources/Assets.xcassets")
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
            name: "DocumentProcessingPipelineTests",
            dependencies: ["DocumentProcessingPipeline"],
            resources: [
                .process("assets")
            ]
        ),
        .testTarget(
            name: "ContentExtractorStoreTests",
            dependencies: [
                "ContentExtractorStore",
                "ArchiverModels",
                "EvaluationCorpus"
            ]
        ),
        .testTarget(
            name: "EvaluationCorpusTests",
            dependencies: [
                "ArchiverModels",
                "EvaluationCorpus"
            ]
        )
    ]
)

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(contentsOf: [
        .swiftLanguageMode(.v6),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances")
    ])
    target.swiftSettings = settings
}
