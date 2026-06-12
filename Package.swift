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
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        // Shared core: model, Keychain, storage, vault export. Used by both
        // the menu bar app and the CLI.
        .target(
            name: "KeyholdrKit"
        ),
        // The menu bar app.
        .executableTarget(
            name: "keyholdr",
            dependencies: [
                "KeyholdrKit",
                .product(name: "MenuBarExtraAccess", package: "MenuBarExtraAccess")
            ]
        ),
        // The terminal companion: keyholdr list / get / run.
        .executableTarget(
            name: "keyholdr-cli",
            dependencies: [
                "KeyholdrKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "keyholdrTests",
            dependencies: ["KeyholdrKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
