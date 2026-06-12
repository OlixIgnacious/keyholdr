import CommonCrypto
import CryptoKit
import Foundation

/// One vault entry in transit: metadata plus the secret pulled from the Keychain.
public struct ExportedKey: Codable {
    public var item: KeyItem
    public var secret: String

    public init(item: KeyItem, secret: String) {
        self.item = item
        self.secret = secret
    }
}

public enum VaultExportError: Error {
    case unsupportedFormat
    case wrongPassphrase
    case keyDerivationFailed
}

/// Passphrase-encrypted vault archive for moving between machines without any
/// sync service: PBKDF2-SHA256 (600k rounds) derives an AES-256-GCM key, and
/// the entire payload — metadata and secrets — travels inside the sealed box.
public enum VaultExport {
    public static let fileExtension = "keyholdr"
    public static let minimumPassphraseLength = 8

    private static let formatVersion = 1
    private static let kdfName = "pbkdf2-sha256"
    private static let kdfIterations = 600_000

    /// The outer JSON wrapper; everything sensitive lives inside `sealed`.
    private struct Envelope: Codable {
        var version: Int
        var kdf: String
        var iterations: Int
        var salt: Data
        var sealed: Data
    }

    public static func export(_ keys: [ExportedKey], passphrase: String) throws -> Data {
        var generator = SystemRandomNumberGenerator()
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max, using: &generator) })

        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: kdfIterations)
        let payload = try JSONEncoder().encode(keys)
        guard let sealed = try AES.GCM.seal(payload, using: key).combined else {
            throw VaultExportError.keyDerivationFailed
        }

        let envelope = Envelope(
            version: formatVersion,
            kdf: kdfName,
            iterations: kdfIterations,
            salt: salt,
            sealed: sealed
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(envelope)
    }

    public static func `import`(_ data: Data, passphrase: String) throws -> [ExportedKey] {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.version == formatVersion,
              envelope.kdf == kdfName else {
            throw VaultExportError.unsupportedFormat
        }

        let key = try deriveKey(passphrase: passphrase, salt: envelope.salt, iterations: envelope.iterations)
        do {
            let box = try AES.GCM.SealedBox(combined: envelope.sealed)
            let payload = try AES.GCM.open(box, using: key)
            return try JSONDecoder().decode([ExportedKey].self, from: payload)
        } catch {
            // GCM authentication failure — almost always a bad passphrase.
            throw VaultExportError.wrongPassphrase
        }
    }

    private static func deriveKey(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        let password = Data(passphrase.utf8)
        var derived = [UInt8](repeating: 0, count: 32)

        let status = salt.withUnsafeBytes { saltBytes in
            password.withUnsafeBytes { passwordBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.bindMemory(to: Int8.self).baseAddress,
                    password.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derived,
                    derived.count
                )
            }
        }

        guard status == kCCSuccess else {
            throw VaultExportError.keyDerivationFailed
        }
        return SymmetricKey(data: Data(derived))
    }
}
