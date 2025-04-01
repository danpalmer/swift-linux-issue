// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-linux-issue",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "swift-linux-issue",
            targets: ["swift-linux-issue"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/Command.git", from: "0.13.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "swift-linux-issue",
            dependencies: [
                .product(name: "Command", package: "Command"),
            ]),
        .testTarget(
            name: "swift-linux-issueTests",
            dependencies: ["swift-linux-issue"]
        ),
    ]
)
