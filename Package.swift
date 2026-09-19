// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// The signed CLI runs inside the app sandbox, and on macOS 27 the sandbox
// refuses to initialise for an executable that carries no bundle identity of
// its own — `keyholdr` died with SIGTRAP before running any code. Embedding an
// Info.plist that names the app's bundle identifier gives it one (and points it
// at the same container as the app, so both read one vault).
let cliInfoPlist = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/keyholdr-cli/EmbeddedInfo.xml")
    .path

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
        // Terminal UI primitives (raw mode, key parsing, text width, editing
        // buffer). Dependency-free, and a library so the tests can reach it.
        .target(
            name: "KeyholdrTUI"
        ),
        // The menu bar app.
        .executableTarget(
            name: "keyholdr",
            dependencies: [
                "KeyholdrKit",
                .product(name: "MenuBarExtraAccess", package: "MenuBarExtraAccess")
            ],
            exclude: ["Keyholdr.entitlements"]
        ),
        // The terminal companion: keyholdr list / get / run.
        .executableTarget(
            name: "keyholdr-cli",
            dependencies: [
                "KeyholdrKit",
                "KeyholdrTUI",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            exclude: ["EmbeddedInfo.xml"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist", "-Xlinker", cliInfoPlist])
            ]
        ),
        .testTarget(
            name: "keyholdrTests",
            dependencies: ["KeyholdrKit", "KeyholdrTUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
