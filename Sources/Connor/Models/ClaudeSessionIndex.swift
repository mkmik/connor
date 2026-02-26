import Foundation

/// Represents the sessions-index.json file Claude stores per project
struct ClaudeSessionIndex: Codable {
    let version: Int
    let entries: [ClaudeSessionEntry]
}

/// A single session entry within the sessions index
struct ClaudeSessionEntry: Codable {
    let sessionId: String
    let summary: String?
}
