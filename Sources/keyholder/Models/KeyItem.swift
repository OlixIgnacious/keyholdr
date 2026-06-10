import Foundation
import SwiftUI

public struct KeyItem: Codable, Identifiable, Hashable {
    public let id: UUID
    public var platform: String
    public var label: String
    public var tags: [String]
    public let dateCreated: Date
    
    public init(id: UUID = UUID(), platform: String, label: String, tags: [String] = [], dateCreated: Date = Date()) {
        self.id = id
        self.platform = platform
        self.label = label
        self.tags = tags
        self.dateCreated = dateCreated
    }
    
    public var symbol: String {
        let p = platform.lowercased()
        if p.contains("github") { return "terminal.fill" }
        if p.contains("aws") || p.contains("amazon") { return "cloud.fill" }
        if p.contains("openai") || p.contains("chatgpt") { return "sparkles" }
        if p.contains("google") { return "globe" }
        if p.contains("stripe") { return "creditcard.fill" }
        if p.contains("db") || p.contains("database") || p.contains("postgres") || p.contains("mysql") || p.contains("mongo") || p.contains("sql") { return "server.rack" }
        if p.contains("ssh") || p.contains("server") || p.contains("vps") { return "network" }
        return "key.fill"
    }
    
    public var symbolColor: Color {
        let p = platform.lowercased()
        if p.contains("github") { return .purple }
        if p.contains("aws") || p.contains("amazon") { return .orange }
        if p.contains("openai") || p.contains("chatgpt") { return .teal }
        if p.contains("google") { return .blue }
        if p.contains("stripe") { return .indigo }
        if p.contains("db") || p.contains("database") || p.contains("postgres") || p.contains("mysql") || p.contains("mongo") || p.contains("sql") { return .green }
        if p.contains("ssh") || p.contains("server") || p.contains("vps") { return .gray }
        return .yellow
    }
}
