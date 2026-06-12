import Foundation
import SwiftUI

public struct KeyItem: Codable, Identifiable, Hashable {
    public let id: UUID
    public var platform: String
    public var label: String
    public var tags: [String]
    public let dateCreated: Date
    /// When the secret value last changed. Optional so keys.json files written
    /// before this field existed still decode; falls back to dateCreated.
    public var secretUpdatedAt: Date?

    public init(id: UUID = UUID(), platform: String, label: String, tags: [String] = [], dateCreated: Date = Date(), secretUpdatedAt: Date? = nil) {
        self.id = id
        self.platform = platform
        self.label = label
        self.tags = tags
        self.dateCreated = dateCreated
        self.secretUpdatedAt = secretUpdatedAt
    }

    // MARK: - Secret age

    /// Secrets older than this are flagged for rotation.
    public static let staleAfter: TimeInterval = 60 * 60 * 24 * 180

    public var secretLastChanged: Date {
        secretUpdatedAt ?? dateCreated
    }

    public var isStale: Bool {
        Date().timeIntervalSince(secretLastChanged) > Self.staleAfter
    }

    /// Compact age like "5d", "3w", "11mo", "2y".
    public var compactAge: String {
        let days = Int(Date().timeIntervalSince(secretLastChanged) / 86_400)
        switch days {
        case ..<14: return "\(max(days, 0))d"
        case ..<60: return "\(days / 7)w"
        case ..<548: return "\(days / 30)mo"
        default: return "\(days / 365)y"
        }
    }
    
    /// Two-letter tile monogram, e.g. "GitHub" → "GH", "OpenAI" → "OA", "AWS" → "AW".
    public var initials: String {
        let trimmed = platform.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "??" }

        // Split on whitespace and lowercase→uppercase camelCase boundaries
        var words: [String] = []
        var current = ""
        for char in trimmed {
            if char.isWhitespace {
                if !current.isEmpty { words.append(current); current = "" }
            } else if char.isUppercase, let last = current.last, last.isLowercase {
                words.append(current)
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { words.append(current) }

        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    public var symbol: String {
        let p = platform.lowercased()
        
        // AI / ML
        if p.contains("openai") || p.contains("chatgpt") || p.contains("claude") || p.contains("anthropic") || p.contains("gemini") || p.contains("huggingface") || p.contains("cohere") || p.contains("deepseek") || p.contains("ollama") {
            return "sparkles"
        }
        
        // Version Control
        if p.contains("github") || p.contains("gitlab") || p.contains("bitbucket") || p.contains("git") {
            return "terminal.fill"
        }
        
        // Cloud & Hosting
        if p.contains("aws") || p.contains("amazon") || p.contains("azure") || p.contains("cloudflare") || p.contains("digitalocean") || p.contains("heroku") || p.contains("vercel") || p.contains("netlify") || p.contains("fly.io") || p.contains("render") {
            return "cloud.fill"
        }
        
        // Databases / Backend services
        if p.contains("db") || p.contains("database") || p.contains("postgres") || p.contains("mysql") || p.contains("mongo") || p.contains("sql") || p.contains("redis") || p.contains("supabase") || p.contains("firebase") || p.contains("dynamodb") || p.contains("prisma") || p.contains("hasura") {
            return "server.rack"
        }
        
        // Payments & E-commerce
        if p.contains("stripe") || p.contains("paypal") || p.contains("braintree") || p.contains("adyen") || p.contains("coinbase") || p.contains("shopify") {
            return "creditcard.fill"
        }
        
        // Servers & Networking
        if p.contains("ssh") || p.contains("server") || p.contains("vps") || p.contains("docker") || p.contains("k8s") || p.contains("kubernetes") || p.contains("nginx") {
            return "network"
        }
        
        // Communication, Collaboration & Productivity
        if p.contains("slack") || p.contains("discord") || p.contains("telegram") || p.contains("teams") || p.contains("zoom") || p.contains("notion") || p.contains("figma") || p.contains("jira") || p.contains("linear") {
            return "bubble.left.and.bubble.right.fill"
        }
        
        // Monitoring, Logging & Analytics
        if p.contains("sentry") || p.contains("datadog") || p.contains("grafana") || p.contains("prometheus") || p.contains("mixpanel") || p.contains("amplitude") {
            return "waveform.path.ecg"
        }
        
        // Email, SMS & Messaging APIs
        if p.contains("twilio") || p.contains("sendgrid") || p.contains("mailchimp") || p.contains("postmark") || p.contains("ses") {
            return "paperplane.fill"
        }
        
        // Search & Public APIs
        if p.contains("google") {
            return "globe"
        }
        
        return "key.fill"
    }
    
    public var symbolColor: Color {
        let p = platform.lowercased()
        
        // AI / ML
        if p.contains("openai") || p.contains("chatgpt") { return .teal }
        if p.contains("claude") || p.contains("anthropic") { return .orange }
        if p.contains("gemini") { return .purple }
        if p.contains("huggingface") { return .yellow }
        if p.contains("deepseek") { return .blue }
        
        // Version Control
        if p.contains("github") { return .purple }
        if p.contains("gitlab") { return .orange }
        if p.contains("bitbucket") { return .blue }
        if p.contains("git") { return .orange }
        
        // Cloud & Providers
        if p.contains("aws") || p.contains("amazon") { return .orange }
        if p.contains("azure") { return .blue }
        if p.contains("cloudflare") { return .orange }
        if p.contains("digitalocean") { return .blue }
        if p.contains("heroku") { return .purple }
        if p.contains("vercel") { return .primary }
        if p.contains("netlify") { return .cyan }
        
        // Databases & Backend
        if p.contains("supabase") { return .mint }
        if p.contains("firebase") { return .orange }
        if p.contains("postgres") { return .blue }
        if p.contains("redis") { return .red }
        if p.contains("mongo") { return .green }
        if p.contains("db") || p.contains("database") || p.contains("mysql") || p.contains("sql") || p.contains("dynamodb") { return .green }
        
        // Payments
        if p.contains("stripe") { return .indigo }
        if p.contains("paypal") { return .blue }
        if p.contains("shopify") { return .green }
        
        // Networking & VPS
        if p.contains("docker") { return .blue }
        if p.contains("ssh") || p.contains("server") || p.contains("vps") || p.contains("k8s") || p.contains("kubernetes") { return .gray }
        
        // Communication & Collaboration
        if p.contains("slack") { return .pink }
        if p.contains("discord") { return .indigo }
        if p.contains("telegram") { return .blue }
        if p.contains("notion") { return .primary }
        if p.contains("figma") { return .purple }
        
        // Monitoring
        if p.contains("sentry") { return .purple }
        if p.contains("datadog") { return .orange }
        
        // Mailing
        if p.contains("twilio") { return .red }
        if p.contains("sendgrid") || p.contains("mailchimp") { return .blue }
        
        // Google ecosystem
        if p.contains("google") { return .blue }
        
        return .yellow
    }
}
