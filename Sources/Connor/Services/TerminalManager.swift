import Foundation
import SwiftUI
import SwiftTerm

/// Manages persistent terminal views across workspace switches.
/// Caches LocalProcessTerminalView instances keyed by workspace/terminal ID,
/// allowing sessions to persist when switching between workspaces.
@MainActor
final class TerminalManager: ObservableObject {
    static let shared = TerminalManager()

    /// Cached terminal views keyed by composite ID (workspaceId:terminalId or workspaceId:claude)
    private var terminals: [String: CachedTerminal] = [:]

    /// Currently selected workspace (used to prevent eviction of active workspace)
    var currentWorkspaceId: UUID?

    /// Maximum number of cached terminals for memory management
    private let maxCachedTerminals: Int = 10

    private init() {}

    // MARK: - Public API

    /// Gets or creates a Claude terminal for the specified workspace.
    func claudeTerminal(for workspaceId: UUID, workingDirectory: URL) -> LocalProcessTerminalView {
        let key = claudeKey(for: workspaceId)
        return terminal(for: key, workingDirectory: workingDirectory, isClaude: true)
    }

    /// Gets or creates an additional terminal for the specified workspace and terminal ID.
    func additionalTerminal(
        for workspaceId: UUID,
        terminalId: UUID,
        workingDirectory: URL,
        command: String,
        arguments: [String]
    ) -> LocalProcessTerminalView {
        let key = terminalKey(for: workspaceId, terminalId: terminalId)
        return terminal(
            for: key,
            workingDirectory: workingDirectory,
            isClaude: false,
            command: command,
            arguments: arguments
        )
    }

    /// Removes all terminals for a workspace (called when workspace is deleted).
    func removeTerminals(for workspaceId: UUID) {
        let prefix = "\(workspaceId.uuidString):"
        let keysToRemove = terminals.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            terminals.removeValue(forKey: key)
        }
    }

    /// Removes a specific terminal (called when additional terminal tab is closed).
    func removeTerminal(for workspaceId: UUID, terminalId: UUID) {
        let key = terminalKey(for: workspaceId, terminalId: terminalId)
        terminals.removeValue(forKey: key)
    }

    /// Checks if a Claude terminal exists for the workspace.
    func hasClaudeTerminal(for workspaceId: UUID) -> Bool {
        terminals[claudeKey(for: workspaceId)] != nil
    }

    /// Restarts the Claude process for a workspace (called when process terminates).
    func restartClaude(for workspaceId: UUID, workingDirectory: URL) {
        let key = claudeKey(for: workspaceId)
        guard let cached = terminals[key] else { return }

        // Build environment
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        let envStrings = env.map { "\($0.key)=\($0.value)" }

        // Restart claude process
        cached.terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-c", "cd \"\(workingDirectory.path)\" && exec claude"],
            environment: envStrings,
            execName: "claude"
        )
    }

    // MARK: - Private Implementation

    private func claudeKey(for workspaceId: UUID) -> String {
        "\(workspaceId.uuidString):claude"
    }

    private func terminalKey(for workspaceId: UUID, terminalId: UUID) -> String {
        "\(workspaceId.uuidString):\(terminalId.uuidString)"
    }

    private func terminal(
        for key: String,
        workingDirectory: URL,
        isClaude: Bool,
        command: String? = nil,
        arguments: [String] = []
    ) -> LocalProcessTerminalView {
        // Return existing terminal if cached
        if let cached = terminals[key] {
            cached.lastAccessed = Date()
            return cached.terminalView
        }

        // Evict old terminals if at capacity
        evictIfNeeded()

        // Create new terminal
        let terminalView = createTerminal(
            workingDirectory: workingDirectory,
            isClaude: isClaude,
            command: command,
            arguments: arguments
        )

        terminals[key] = CachedTerminal(
            terminalView: terminalView,
            isClaude: isClaude,
            workingDirectory: workingDirectory
        )

        return terminalView
    }

    private func createTerminal(
        workingDirectory: URL,
        isClaude: Bool,
        command: String?,
        arguments: [String]
    ) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Configure appearance
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.optionAsMetaKey = true
        terminalView.nativeBackgroundColor = .white
        terminalView.nativeForegroundColor = .black

        // Build environment
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        let envStrings = env.map { "\($0.key)=\($0.value)" }

        if isClaude {
            // Start claude via shell
            terminalView.startProcess(
                executable: "/bin/zsh",
                args: ["-c", "cd \"\(workingDirectory.path)\" && exec claude"],
                environment: envStrings,
                execName: "claude"
            )
        } else {
            // Start regular shell via exec (clean startup without visible cd command)
            let shell = command ?? (env["SHELL"] ?? "/bin/zsh")

            // Shell-escape arguments using single quotes
            let quotedArgs = arguments.map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
            let argsStr = quotedArgs.isEmpty ? "" : " " + quotedArgs.joined(separator: " ")

            terminalView.startProcess(
                executable: "/bin/zsh",
                args: ["-c", "cd \"\(workingDirectory.path)\" && exec \(shell)\(argsStr)"],
                environment: envStrings,
                execName: shell
            )
        }

        return terminalView
    }

    private func evictIfNeeded() {
        guard terminals.count >= maxCachedTerminals else { return }

        // Find least recently accessed terminal that isn't in the current workspace
        let sortedByAccess = terminals
            .filter { key, _ in
                // Don't evict terminals from the current workspace
                guard let currentId = currentWorkspaceId else { return true }
                return !key.hasPrefix(currentId.uuidString)
            }
            .sorted { $0.value.lastAccessed < $1.value.lastAccessed }

        if let oldest = sortedByAccess.first {
            terminals.removeValue(forKey: oldest.key)
        }
    }
}

/// Wrapper for cached terminal with metadata
private final class CachedTerminal {
    let terminalView: LocalProcessTerminalView
    let isClaude: Bool
    let workingDirectory: URL
    var lastAccessed: Date

    init(terminalView: LocalProcessTerminalView, isClaude: Bool, workingDirectory: URL) {
        self.terminalView = terminalView
        self.isClaude = isClaude
        self.workingDirectory = workingDirectory
        self.lastAccessed = Date()
    }
}
