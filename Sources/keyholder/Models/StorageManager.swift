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
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([KeyItem].self, from: data)
        } catch {
            print("Error loading key metadata: \(error)")
            return []
        }
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
        } catch {
            print("Error saving key metadata: \(error)")
        }
    }
}
