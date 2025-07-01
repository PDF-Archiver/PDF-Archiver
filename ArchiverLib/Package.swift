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
            targets: ["Features"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.20.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "Features",
                dependencies: [
                    "DomainModels",
                    "Shared",
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
                ]),
//        .target(name: "DocumentDetails",
//                dependencies: [
//                    "DomainModels",
//                    "Shared",
//                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
//                ]),
//        .target(name: "DocumentInformationForm",
//                dependencies: [
//                    "DomainModels",
//                    "Shared",
//                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
//                ]),
        .target(name: "Shared",
                dependencies: [
                    "DomainModels",
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
                ]),
        .target(name: "DomainModels",
                dependencies: []),
//                swiftSettings: [.defaultIsolaion(MainActor.self)]),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features"]
        ),
    ]
)
