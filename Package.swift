// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GameServerQueryLibrary",
    platforms: [
        // Add support for all platforms starting from a specific version.
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "GameServerQueryLibrary",
            targets: ["GameServerQueryLibrary"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "GameServerQueryLibrary",
            dependencies: [.product(name: "AsyncAlgorithms", package: "swift-async-algorithms")],
            path: "GameServerQueryLibrary"
        )
    ]
)
