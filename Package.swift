// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "keyholdr",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Programmatic open/close for MenuBarExtra, used by the global hotkey.
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "keyholdr",
            dependencies: [
                .product(name: "MenuBarExtraAccess", package: "MenuBarExtraAccess")
            ]
        ),
        .testTarget(
            name: "keyholdrTests",
            dependencies: ["keyholdr"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
