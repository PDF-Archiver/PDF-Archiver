// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

// https://docs.swift.org/package-manager/PackageDescription/index.html
// https://developer.apple.com/documentation/swift_packages/package
// https://swift.org/package-manager/

import PackageDescription

let package = Package(
    name: "ArchiveCore",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "ArchiveBackend", targets: ["ArchiveBackend"]),
        .library(name: "ArchiveViews", targets: ["ArchiveViews"]),
        .library(name: "InAppPurchases", targets: ["InAppPurchases"]),
        .library(name: "ArchiveSharedConstants", targets: ["ArchiveSharedConstants"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
        .package(url: "https://github.com/onmyway133/DeepDiff.git", from: "2.3.3"),
        .package(url: "https://github.com/SwiftUIX/SwiftUIX", from: "0.1.4"),
        .package(url: "https://github.com/dasautoooo/Parma", from: "0.3.0"),
        .package(url: "https://github.com/WeTransfer/Diagnostics", from: "4.4.0"),
        .package(url: "https://github.com/tikhop/TPInAppReceipt", from: "3.3.4"),
        .package(url: "https://github.com/shaps80/GraphicsRenderer", from: "1.4.4"),
        .package(name: "Sentry", url: "https://github.com/getsentry/sentry-cocoa", from: "8.4.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(name: "ArchiveBackend",
                dependencies: [
                    "ArchiveSharedConstants",
                    "DeepDiff",
                    "GraphicsRenderer"
                ]),
        .target(name: "ArchiveViews",
                dependencies: [
                    "ArchiveBackend",
                    "ArchiveSharedConstants",
                    "SwiftUIX",
                    "Parma",
                    "InAppPurchases",
                    "Diagnostics"
                ]),
        .target(name: "InAppPurchases",
                dependencies: [
                    "ArchiveSharedConstants",
                    "TPInAppReceipt"
                ]),
        .target(name: "ArchiveSharedConstants",
                dependencies: [
                    .product(name: "Logging", package: "swift-log"),
                    "SwiftUIX",
                    "Sentry"
                ]),
        .testTarget(name: "ArchiveBackendTests",
                    dependencies: [
                        "ArchiveBackend",
                        "ArchiveSharedConstants"
                    ],
                    resources: [
                        .copy("assets")
                    ]),
        .testTarget(name: "ArchiveSharedConstantsTests",
                    dependencies: [
                        "ArchiveSharedConstants"
                    ]),
        .testTarget(name: "ArchiveViewsTests",
                    dependencies: [
                        "ArchiveViews"
                    ])
    ]
)
