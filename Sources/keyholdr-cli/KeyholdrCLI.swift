import AppKit
import ArgumentParser
import Foundation
import KeyholdrKit
import LocalAuthentication

@main
struct KeyholdrCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "keyholdr",
        abstract: "Your keys, one command away.",
        discussion: "Reads the same vault as the Keyholdr menu bar app. Every secret access requires Touch ID (or your password).",
        version: "1.2.0",
        subcommands: [List.self, Get.self, Run.self]
    )
}

// MARK: - list

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show every key in the vault (never the secrets)."
    )

    func run() throws {
        let keys = StorageManager.loadKeys()
            .sorted { $0.platform.localizedCaseInsensitiveCompare($1.platform) == .orderedAscending }
        guard !keys.isEmpty else {
            print("Vault is empty. Add keys from the menu bar app or `keyholdr` ⌃⌥⌘K.")
            return
        }

        let rows = keys.map { key in
            (key.platform, key.label, key.tags.joined(separator: ","), key.compactAge + (key.isStale ? " ⚠" : ""))
        }
        let headers = ("PLATFORM", "LABEL", "TAGS", "AGE")
        let w0 = max(headers.0.count, rows.map { $0.0.count }.max() ?? 0)
        let w1 = max(headers.1.count, rows.map { $0.1.count }.max() ?? 0)
        let w2 = max(headers.2.count, rows.map { $0.2.count }.max() ?? 0)

        func pad(_ s: String, _ w: Int) -> String {
            s.padding(toLength: w, withPad: " ", startingAt: 0)
        }
        print("\(pad(headers.0, w0))  \(pad(headers.1, w1))  \(pad(headers.2, w2))  \(headers.3)")
        for row in rows {
            print("\(pad(row.0, w0))  \(pad(row.1, w1))  \(pad(row.2, w2))  \(row.3)")
        }
    }
}

// MARK: - get

struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print a secret to stdout after biometric verification."
    )

    @Argument(help: "Platform name, e.g. github or openai (case-insensitive).")
    var platform: String

    @Option(name: .shortAndLong, help: "Disambiguate when one platform has several keys.")
    var label: String?

    @Flag(name: .shortAndLong, help: "Copy to the clipboard instead of printing.")
    var copy = false

    func run() throws {
        let key = try resolveKey(platform: platform, label: label)
        try authenticateOrExit(reason: "read the secret for \(key.platform)")

        guard let secret = KeychainHelper.retrieve(for: key.id) else {
            throw ValidationError("No secret in the Keychain for \(key.platform) (\(key.label)).")
        }

        if copy {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(secret, forType: .string)
            FileHandle.standardError.write(Data("Copied \(key.platform) (\(key.label)) to the clipboard.\n".utf8))
        } else {
            print(secret)
        }
    }
}

// MARK: - run

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Run a command with secrets injected as environment variables.",
        discussion: """
        Secrets never touch stdout, files, or shell history — they exist only
        in the child process environment.

            keyholdr run -e OPENAI_API_KEY=openai -e GITHUB_TOKEN=github/work -- npm start
        """
    )

    @Option(
        name: .customShort("e"),
        help: ArgumentHelp("ENV_VAR=platform or ENV_VAR=platform/label mapping.", valueName: "mapping")
    )
    var env: [String] = []

    @Argument(parsing: .postTerminator, help: "The command to run (after --).")
    var command: [String] = []

    func validate() throws {
        guard !env.isEmpty else { throw ValidationError("Provide at least one -e ENV_VAR=key mapping.") }
        guard !command.isEmpty else { throw ValidationError("Provide a command after `--`.") }
    }

    func run() throws {
        // Resolve every mapping up front so typos fail before Touch ID.
        var injected: [(name: String, key: KeyItem)] = []
        for mapping in env {
            guard let eq = mapping.firstIndex(of: "="), eq != mapping.startIndex else {
                throw ValidationError("Mapping '\(mapping)' is not ENV_VAR=key.")
            }
            let name = String(mapping[..<eq])
            let ref = String(mapping[mapping.index(after: eq)...])
            let parts = ref.split(separator: "/", maxSplits: 1).map(String.init)
            let key = try resolveKey(platform: parts[0], label: parts.count > 1 ? parts[1] : nil)
            injected.append((name, key))
        }

        let names = injected.map { $0.key.platform }.joined(separator: ", ")
        try authenticateOrExit(reason: "inject secrets for \(names)")

        var environment = ProcessInfo.processInfo.environment
        for entry in injected {
            guard let secret = KeychainHelper.retrieve(for: entry.key.id) else {
                throw ValidationError("No secret in the Keychain for \(entry.key.platform) (\(entry.key.label)).")
            }
            environment[entry.name] = secret
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.environment = environment
        try process.run()
        process.waitUntilExit()
        throw ExitCode(process.terminationStatus)
    }
}

// MARK: - Shared helpers

func resolveKey(platform: String, label: String?) throws -> KeyItem {
    let keys = StorageManager.loadKeys()
    var matches = keys.filter { $0.platform.caseInsensitiveCompare(platform) == .orderedSame }
    if matches.isEmpty {
        // Fall back to prefix/substring so `keyholdr get open` finds OpenAI.
        matches = keys.filter { $0.platform.range(of: platform, options: .caseInsensitive) != nil }
    }
    if let label {
        matches = matches.filter { $0.label.caseInsensitiveCompare(label) == .orderedSame }
    }

    switch matches.count {
    case 1:
        return matches[0]
    case 0:
        throw ValidationError("No key matches '\(platform)'\(label.map { " with label '\($0)'" } ?? ""). Try `keyholdr list`.")
    default:
        let labels = matches.map { "--label \($0.label)" }.joined(separator: " | ")
        throw ValidationError("'\(platform)' is ambiguous — disambiguate with: \(labels)")
    }
}

/// Blocks on a biometric (or password) check. Mirrors the app's behavior of
/// passing automatically when LocalAuthentication is unavailable (CI, VMs).
func authenticateOrExit(reason: String) throws {
    final class ResultBox: @unchecked Sendable { var success = false }

    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }

    FileHandle.standardError.write(Data("● Touch ID — \(reason)\n".utf8))
    let box = ResultBox()
    let semaphore = DispatchSemaphore(value: 0)
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
        box.success = ok
        semaphore.signal()
    }
    semaphore.wait()

    guard box.success else {
        FileHandle.standardError.write(Data("Authentication failed.\n".utf8))
        throw ExitCode(1)
    }
}
