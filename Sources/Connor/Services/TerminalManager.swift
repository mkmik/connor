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

    /// Observer for theme changes
    private var themeObserver: NSObjectProtocol?

    /// Observer for font preference changes
    private var fontObserver: NSObjectProtocol?

    private init() {
        // Subscribe to theme changes
        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let theme = notification.userInfo?["theme"] as? Theme else { return }
            guard let self = self else { return }
            Task { @MainActor [self] in
                self.applyTheme(theme)
            }
        }

        // Subscribe to font preference changes
        fontObserver = NotificationCenter.default.addObserver(
            forName: .fontPreferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let fontSize = notification.userInfo?["fontSize"] as? CGFloat else { return }
            let fontName = notification.userInfo?["fontName"] as? String
            guard let self = self else { return }
            Task { @MainActor [self] in
                self.applyFont(size: fontSize, name: fontName)
            }
        }
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = fontObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Theme Application

    /// Updates all cached terminal backgrounds to match the current theme
    func applyTheme(_ theme: Theme) {
        for (key, cached) in terminals {
            let isClaudeTerminal = key.hasSuffix(":claude")
            let backgroundColor = isClaudeTerminal
                ? theme.centralTerminalBackground.nsColor
                : theme.rightTerminalBackground.nsColor
            cached.terminalView.nativeBackgroundColor = backgroundColor
            cached.terminalView.nativeForegroundColor = ThemeManager.contrastingColor(for: backgroundColor)
        }
    }

    /// Updates all cached terminal fonts
    func applyFont(size: CGFloat, name: String?) {
        let font: NSFont
        if let name = name, let customFont = NSFont(name: name, size: size) {
            font = customFont
        } else {
            font = NSFont.monospacedSystemFont(ofSize: size, weight: .thin)
        }
        for (_, cached) in terminals {
            cached.terminalView.font = font
        }
    }

    // MARK: - Public API

    /// Gets or creates a Claude terminal for the specified workspace.
    func claudeTerminal(for workspaceId: UUID, workingDirectory: URL) -> LocalProcessTerminalView {
        let key = claudeKey(for: workspaceId)
        return terminal(for: key, workspaceId: workspaceId, workingDirectory: workingDirectory, isClaude: true)
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
            workspaceId: workspaceId,
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

        // Restart claude process with session handling
        let claudeCmd = claudeCommand(for: workspaceId)
        cached.terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-c", "cd \"\(workingDirectory.path)\" && \(claudeCmd)"],
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

    /// Generates the shell command to start claude with appropriate session handling.
    /// Uses --resume if a session file exists, otherwise --session-id.
    private func claudeCommand(for workspaceId: UUID) -> String {
        let sessionId = workspaceId.uuidString.lowercased()
        return """
            clear
            if find ~/.claude/projects -maxdepth 2 -name '\(sessionId).jsonl' -print -quit 2>/dev/null | grep -q .; then
                exec claude --resume \(sessionId)
            else
                exec claude --session-id \(sessionId)
            fi
            """
    }

    private func terminal(
        for key: String,
        workspaceId: UUID,
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
            workspaceId: workspaceId,
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
        workspaceId: UUID,
        workingDirectory: URL,
        isClaude: Bool,
        command: String?,
        arguments: [String]
    ) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Configure appearance
        let prefs = AppState.shared.preferences
        let font: NSFont
        if let fontName = prefs.monospaceFontName, let customFont = NSFont(name: fontName, size: prefs.monospaceFontSize) {
            font = customFont
        } else {
            font = NSFont.monospacedSystemFont(ofSize: prefs.monospaceFontSize, weight: .light)
        }
        terminalView.font = font
        terminalView.optionAsMetaKey = true

        // Use theme colors
        let theme = ThemeManager.shared.currentTheme
        let backgroundColor = isClaude
            ? theme.centralTerminalBackground.nsColor
            : theme.rightTerminalBackground.nsColor
        terminalView.nativeBackgroundColor = backgroundColor
        terminalView.nativeForegroundColor = ThemeManager.contrastingColor(for: backgroundColor)

        // Build environment
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        let envStrings = env.map { "\($0.key)=\($0.value)" }

        if isClaude {
            // Start claude via shell with session handling
            let claudeCmd = claudeCommand(for: workspaceId)
            terminalView.startProcess(
                executable: "/bin/zsh",
                args: ["-c", "cd \"\(workingDirectory.path)\" && \(claudeCmd)"],
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
