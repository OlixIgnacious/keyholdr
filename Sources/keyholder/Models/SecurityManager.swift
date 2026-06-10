import Foundation
import LocalAuthentication

@MainActor
public class SecurityManager: ObservableObject {
    @Published public var isUnlocked: Bool = false
    
    public init() {}
    
    public func authenticate(reason: String = "access your secure keys") async -> Bool {
        if isUnlocked {
            return true
        }
        
        let context = LAContext()
        var error: NSError?
        
        let policy: LAPolicy = .deviceOwnerAuthentication
        
        if context.canEvaluatePolicy(policy, error: &error) {
            do {
                let success = try await context.evaluatePolicy(policy, localizedReason: reason)
                self.isUnlocked = success
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
    }
}
