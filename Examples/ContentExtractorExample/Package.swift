// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ContentExtractorExample",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(
            name: "ContentExtractorExample",
            targets: ["ContentExtractorExample"])
    ],
    targets: [
        .target(
            name: "ContentExtractorExample",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ContentExtractorExampleTests",
            dependencies: ["ContentExtractorExample"]
        )
    ]
)
