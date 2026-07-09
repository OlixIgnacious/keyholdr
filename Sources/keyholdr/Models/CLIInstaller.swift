import Foundation

/// Installs the bundled keyholdr-cli binary to ~/.local/bin and optionally
/// patches the user's shell profile so it's immediately on PATH.
enum CLIInstaller {
    enum InstallResult {
        case alreadyInstalled
        case installed(pathPatched: Bool)
        case failed(String)
    }

    static var installPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/keyholdr")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installPath.path)
    }

    static func install() -> InstallResult {
        guard let cliSource = Bundle.main.url(
            forResource: "keyholdr-cli",
            withExtension: nil,
            subdirectory: "Contents/MacOS"
        ) ?? bundledCLI() else {
            return .failed("Could not locate keyholdr-cli in the app bundle.")
        }

        let binDir = installPath.deletingLastPathComponent()
        let fm = FileManager.default

        do {
            if !fm.fileExists(atPath: binDir.path) {
                try fm.createDirectory(at: binDir, withIntermediateDirectories: true)
            }
            if fm.fileExists(atPath: installPath.path) {
                try fm.removeItem(at: installPath)
            }
            try fm.copyItem(at: cliSource, to: installPath)
            // Ensure the copy is executable.
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installPath.path)
        } catch {
            return .failed(error.localizedDescription)
        }

        let patched = patchShellProfile()
        return .installed(pathPatched: patched)
    }

    // MARK: - Private

    private static func bundledCLI() -> URL? {
        // When running from the built app bundle the CLI sits at
        // Contents/MacOS/keyholdr-cli alongside the main executable.
        guard let execURL = Bundle.main.executableURL else { return nil }
        let candidate = execURL.deletingLastPathComponent()
            .appendingPathComponent("keyholdr-cli")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    /// Returns true if the profile was patched (or already contained the export).
    @discardableResult
    private static func patchShellProfile() -> Bool {
        let exportLine = "export PATH=\"$HOME/.local/bin:$PATH\""
        let home = FileManager.default.homeDirectoryForCurrentUser

        // Check if ~/.local/bin is already in the current PATH first.
        if let path = ProcessInfo.processInfo.environment["PATH"],
           path.contains(".local/bin") {
            return false
        }

        // Pick the right shell profile based on $SHELL.
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        let profileNames: [String]
        if shell.hasSuffix("zsh") {
            profileNames = [".zshrc", ".zprofile"]
        } else if shell.hasSuffix("fish") {
            // fish uses a different syntax; skip auto-patching.
            return false
        } else {
            profileNames = [".bash_profile", ".bashrc"]
        }

        for name in profileNames {
            let profileURL = home.appendingPathComponent(name)
            let fm = FileManager.default
            do {
                var existing = ""
                if fm.fileExists(atPath: profileURL.path) {
                    existing = try String(contentsOf: profileURL, encoding: .utf8)
                }
                guard !existing.contains(".local/bin") else { return false }
                let addition = "\n# Added by Keyholdr\n\(exportLine)\n"
                if fm.fileExists(atPath: profileURL.path) {
                    let handle = try FileHandle(forWritingTo: profileURL)
                    handle.seekToEndOfFile()
                    if let data = addition.data(using: .utf8) { handle.write(data) }
                    handle.closeFile()
                } else {
                    try addition.write(to: profileURL, atomically: true, encoding: .utf8)
                }
                return true
            } catch {
                continue
            }
        }
        return false
    }
}
