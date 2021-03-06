// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GameServerQueryLibrary",
    platforms: [
        // Add support for all platforms starting from a specific version.
        .macOS(.v10_11),
        .iOS(.v12),
        .watchOS(.v4),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "GameServerQueryLibrary",
            targets: ["GameServerQueryLibrary"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", from: "7.6.4")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "GameServerQueryLibrary",
            dependencies: ["CocoaAsyncSocket"],
            path: "Sources"
        ),
        .testTarget(
            name: "GameServerQueryLibraryTests",
            dependencies: ["GameServerQueryLibrary", "CocoaAsyncSocket"],
            path: "Tests"
        ),
    ]
)
