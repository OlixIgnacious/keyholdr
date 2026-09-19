import ArgumentParser
import Foundation
import KeyholdrKit
import LocalAuthentication

// The vault's write rules and the biometric gate, shared by the one-liner
// commands and the full-screen UI so both behave identically.

/// Same guard as the app: an identical platform + label pair would be
/// unaddressable later.
func ensureNewKey(platform: String, label: String, in keys: [KeyItem]) throws {
    if keys.contains(where: {
        $0.platform.caseInsensitiveCompare(platform) == .orderedSame &&
        $0.label.caseInsensitiveCompare(label) == .orderedSame
    }) {
        throw ValidationError("A \(platform) key labeled '\(label)' already exists. Use a different --label.")
    }
}

func parseTags(_ text: String) -> [String] {
    text.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
}

/// Saves the secret to the Keychain and the metadata to keys.json.
@discardableResult
func addKey(platform: String, label: String, tags: [String], secret: String) throws -> KeyItem {
    let keys = StorageManager.loadKeys()
    try ensureNewKey(platform: platform, label: label, in: keys)

    let item = KeyItem(platform: platform, label: label, tags: tags, secretUpdatedAt: Date())
    guard KeychainHelper.save(secret: secret, for: item.id) else {
        throw ValidationError("Couldn't write the secret to the Keychain.")
    }
    StorageManager.saveKeys(keys + [item])
    return item
}

/// Erases the secrets from the Keychain and the entries from keys.json.
func deleteKeys(_ targets: [KeyItem]) {
    let ids = Set(targets.map(\.id))
    for id in ids { KeychainHelper.delete(for: id) }
    var keys = StorageManager.loadKeys()
    keys.removeAll { ids.contains($0.id) }
    StorageManager.saveKeys(keys)
}

enum AuthOutcome {
    /// Verified — or LocalAuthentication is unavailable (CI, VMs), in which
    /// case there is no context and Keychain reads need none.
    case authenticated(LAContext?)
    case denied
}

/// Blocks on a biometric (or password) check without printing or throwing,
/// so a full-screen UI can call it without scribbling over its own display.
/// `announce` prints the one-line "● Touch ID" hint the one-liners show.
func authenticate(reason: String, announce: Bool = false) -> AuthOutcome {
    final class ResultBox: @unchecked Sendable { var success = false }

    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
        return .authenticated(nil)
    }

    if announce {
        FileHandle.standardError.write(Data(Ansi.style("● Touch ID", Ansi.accent, Ansi.bold).appending(" — \(reason)\n").utf8))
    }
    let box = ResultBox()
    let semaphore = DispatchSemaphore(value: 0)
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
        box.success = ok
        semaphore.signal()
    }
    semaphore.wait()
    return box.success ? .authenticated(context) : .denied
}

/// Message text for an error, whether ArgumentParser's or Foundation's.
func message(for error: Error) -> String {
    if let validation = error as? ValidationError { return validation.message }
    return error.localizedDescription
}
