import Foundation
import LocalAuthentication

@MainActor
public class SecurityManager: ObservableObject {
    @Published public var isUnlocked: Bool = false

    /// The `LAContext` that satisfied the most recent authentication, if any.
    /// Pass this to `KeychainHelper.retrieve(for:context:)` so the OS-level
    /// user-presence check on the Keychain item passes without prompting again.
    public private(set) var context: LAContext?

    /// True while a Touch ID / password prompt is in flight. The system prompt
    /// steals focus from the menu bar popover, which causes it to auto-close;
    /// observers can use this to know when to re-present the popover once the
    /// prompt is dismissed.
    @Published public private(set) var isAuthenticating: Bool = false

    public init() {}

    public func authenticate(reason: String = "access your secure keys") async -> Bool {
        if isUnlocked {
            return true
        }

        let context = LAContext()
        var error: NSError?

        let policy: LAPolicy = .deviceOwnerAuthentication

        if context.canEvaluatePolicy(policy, error: &error) {
            isAuthenticating = true
            defer { isAuthenticating = false }
            do {
                let success = try await context.evaluatePolicy(policy, localizedReason: reason)
                self.isUnlocked = success
                if success { self.context = context }
                return success
            } catch {
                print("Authentication error: \(error)")
                return false
            }
        } else {
            // Local Authentication not supported/enabled on this machine (e.g. CI/CD or VM context)
            self.isUnlocked = true
            return true
        }
    }

    public func lock() {
        isUnlocked = false
        context = nil
    }
}
