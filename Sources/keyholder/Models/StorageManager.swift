import Foundation

public struct StorageManager {
    private static var directoryURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0]
        return appSupportDir.appendingPathComponent("com.olixstudios.KeyHolder", isDirectory: true)
    }
    
    private static var fileURL: URL {
        return directoryURL.appendingPathComponent("keys.json")
    }
    
    public static func loadKeys() -> [KeyItem] {
        let url = fileURL

        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let keys = try JSONDecoder().decode([KeyItem].self, from: data)
                // Seed the mirror for installs that predate it.
                if KeychainHelper.retrieveMetadataBackup() == nil {
                    KeychainHelper.saveMetadataBackup(data)
                }
                return keys
            } catch {
                print("Error loading key metadata: \(error)")
                // File is corrupt — fall through to the Keychain backup.
            }
        }

        return restoreFromBackup()
    }

    /// Rebuilds keys.json from the Keychain-stored mirror when the file is
    /// missing or unreadable, so accidental deletion loses nothing.
    private static func restoreFromBackup() -> [KeyItem] {
        guard let data = KeychainHelper.retrieveMetadataBackup(),
              let keys = try? JSONDecoder().decode([KeyItem].self, from: data),
              !keys.isEmpty else {
            return []
        }

        print("keys.json missing or unreadable — restored \(keys.count) entries from Keychain backup")
        saveKeys(keys)
        return keys
    }
    
    public static func saveKeys(_ keys: [KeyItem]) {
        let dir = directoryURL
        let url = fileURL
        
        do {
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            }
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(keys)
            try data.write(to: url, options: .atomic)
            KeychainHelper.saveMetadataBackup(data)
        } catch {
            print("Error saving key metadata: \(error)")
        }
    }
}
