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
        discussion: "Reads the same vault as the Keyholdr menu bar app. Every secret access requires Touch ID (or your password). Run with no arguments to browse interactively.",
        version: "1.4.0",
        subcommands: [Pick.self, List.self, Get.self, Run.self, Add.self, Remove.self],
        defaultSubcommand: Pick.self
    )
}

// MARK: - add

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a key. The secret comes from a hidden prompt or stdin — never from arguments.",
        discussion: """
        Arguments are visible to every process on the machine (`ps`), so the
        secret is read interactively with echo off, or piped:

            keyholdr add github --label work --tags dev,ci
            pbpaste | keyholdr add openai
        """
    )

    @Argument(help: "Platform name, e.g. github or openai.")
    var platform: String

    @Option(name: .shortAndLong, help: "Label to tell multiple keys for one platform apart.")
    var label: String = "default"

    @Option(name: .shortAndLong, help: "Comma-separated tags.")
    var tags: String = ""

    func run() throws {
        let keys = StorageManager.loadKeys()
        // Same guard as the app: an identical platform + label pair would be
        // unaddressable later.
        if keys.contains(where: {
            $0.platform.caseInsensitiveCompare(platform) == .orderedSame &&
            $0.label.caseInsensitiveCompare(label) == .orderedSame
        }) {
            throw ValidationError("A \(platform) key labeled '\(label)' already exists. Use a different --label.")
        }

        guard let secret = readSecret(prompt: "Secret for \(platform) (\(label)) — input hidden: "),
              !secret.isEmpty else {
            throw ValidationError("No secret provided.")
        }

        let tagList = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let item = KeyItem(platform: platform, label: label, tags: tagList, secretUpdatedAt: Date())

        guard KeychainHelper.save(secret: secret, for: item.id) else {
            throw ValidationError("Couldn't write the secret to the Keychain.")
        }
        StorageManager.saveKeys(keys + [item])
        FileHandle.standardError.write(Data("Added \(platform) (\(label)).\n".utf8))
    }
}

// MARK: - rm

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Delete keys and their secrets from the Keychain.",
        discussion: "With no platform argument, opens a multi-select picker — ⇥ or space to mark several keys, ⏎ to confirm."
    )

    @Argument(help: "Platform name (case-insensitive). Omit to multi-select interactively.")
    var platform: String?

    @Option(name: .shortAndLong, help: "Disambiguate when one platform has several keys.")
    var label: String?

    @Flag(name: [.customShort("f"), .long], help: "Skip the confirmation prompt.")
    var force = false

    func run() throws {
        let targets: [KeyItem]
        if let platform {
            targets = [try resolveKey(platform: platform, label: label, interactive: true)]
        } else {
            guard Picker.isInteractive else {
                throw ValidationError("Provide a platform name, or run in a terminal to multi-select.")
            }
            let keys = StorageManager.loadKeys()
                .sorted { $0.platform.localizedCaseInsensitiveCompare($1.platform) == .orderedAscending }
            guard !keys.isEmpty else {
                print("Vault is empty — nothing to delete.")
                return
            }
            guard let picked = Picker.pickMany(from: keys, title: "Delete keys"), !picked.isEmpty else {
                throw ExitCode(130) // cancelled
            }
            targets = picked
        }

        if !force {
            guard Picker.isInteractive else {
                throw ValidationError("Refusing to delete without confirmation — pass --force in scripts.")
            }
            let names = targets.map { "\($0.platform) (\($0.label))" }.joined(separator: ", ")
            let what = targets.count == 1 ? names : "\(targets.count) keys — \(names) —"
            FileHandle.standardError.write(Data("Delete \(what) and permanently erase the secret\(targets.count == 1 ? "" : "s")? [y/N] ".utf8))
            guard readLine()?.trimmingCharacters(in: .whitespaces).lowercased() == "y" else {
                throw ExitCode(1)
            }
        }

        let ids = Set(targets.map(\.id))
        for id in ids { KeychainHelper.delete(for: id) }
        var keys = StorageManager.loadKeys()
        keys.removeAll { ids.contains($0.id) }
        StorageManager.saveKeys(keys)
        for target in targets {
            FileHandle.standardError.write(Data("Removed \(target.platform) (\(target.label)).\n".utf8))
        }
    }
}

/// Reads a secret without echoing it; from stdin when piped.
func readSecret(prompt: String) -> String? {
    guard isatty(STDIN_FILENO) != 0 else {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let err = FileHandle.standardError
    err.write(Data(prompt.utf8))
    var original = termios()
    tcgetattr(STDIN_FILENO, &original)
    var noEcho = original
    noEcho.c_lflag &= ~UInt(ECHO)
    tcsetattr(STDIN_FILENO, TCSANOW, &noEcho)
    defer {
        tcsetattr(STDIN_FILENO, TCSANOW, &original)
        err.write(Data("\n".utf8))
    }
    return readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - pick (default)

struct Pick: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Browse the vault interactively; ⏎ copies after Touch ID."
    )

    @Argument(help: "Optional initial filter, e.g. `keyholdr pick aws`.")
    var filter: String = ""

    func run() throws {
        guard Picker.isInteractive else {
            throw ValidationError("Interactive mode needs a terminal. Try `keyholdr list` or `keyholdr get <platform>`.")
        }
        let keys = StorageManager.loadKeys()
            .sorted { $0.platform.localizedCaseInsensitiveCompare($1.platform) == .orderedAscending }
        guard !keys.isEmpty else {
            print("Vault is empty. Add keys from the menu bar app (⌃⌥⌘K).")
            return
        }
        guard let choice = Picker.pick(from: keys, title: "Keyholdr", initialFilter: filter) else {
            throw ExitCode(130) // cancelled
        }

        try authenticateOrExit(reason: "copy the secret for \(choice.platform)")
        guard let secret = KeychainHelper.retrieve(for: choice.id) else {
            throw ValidationError("No secret in the Keychain for \(choice.platform) (\(choice.label)).")
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(secret, forType: .string)
        FileHandle.standardError.write(Data("Copied \(choice.platform) (\(choice.label)) to the clipboard.\n".utf8))
    }
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
        let key = try resolveKey(platform: platform, label: label, interactive: true)
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

func resolveKey(platform: String, label: String?, interactive: Bool = false) throws -> KeyItem {
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
        // In a terminal, ambiguity becomes a picker; in scripts it stays a
        // hard error so automation never blocks on hidden interactivity.
        if interactive, Picker.isInteractive,
           let chosen = Picker.pick(from: matches, title: "\(matches.count) keys match '\(platform)'") {
            return chosen
        }
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
