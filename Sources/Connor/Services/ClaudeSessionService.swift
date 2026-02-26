import Foundation

/// Service for reading Claude session data from ~/.claude/projects/
final class ClaudeSessionService {
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()

    /// Converts a workspace root path to the Claude project directory name.
    ///
    /// Claude's convention: take the absolute path, replace `/` with `-`,
    /// then remove `.` characters.
    /// Example: /Users/mkm/.connor/helsinki -> -Users-mkm--connor-helsinki
    func claudeProjectDirName(for rootPath: URL) -> String {
        rootPath.path
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "")
    }

    /// Returns the sessions-index.json URL for a given workspace root path.
    func sessionsIndexURL(for rootPath: URL) -> URL {
        let dirName = claudeProjectDirName(for: rootPath)
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
            .appendingPathComponent(dirName)
            .appendingPathComponent("sessions-index.json")
    }

    /// Reads the session summary for a specific sessionId from a workspace's
    /// sessions-index.json. Returns nil if the file doesn't exist, can't be
    /// parsed, or the session has no summary.
    func sessionSummary(for sessionId: UUID, rootPath: URL) -> String? {
        let indexURL = sessionsIndexURL(for: rootPath)

        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL),
              let index = try? decoder.decode(ClaudeSessionIndex.self, from: data) else {
            return nil
        }

        let sessionIdString = sessionId.uuidString.lowercased()
        let entry = index.entries.first { $0.sessionId == sessionIdString }
        return entry?.summary
    }
}
