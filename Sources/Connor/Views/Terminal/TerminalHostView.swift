import SwiftUI
import SwiftTerm

/// NSViewRepresentable wrapper for SwiftTerm's LocalProcessTerminalView
struct TerminalHostView: NSViewRepresentable {
    let workingDirectory: URL
    let command: String
    let arguments: [String]
    let environment: [String: String]

    init(
        workingDirectory: URL,
        command: String = "/bin/zsh",
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) {
        self.workingDirectory = workingDirectory
        self.command = command
        self.arguments = arguments
        self.environment = environment
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Configure terminal appearance
        configureAppearance(terminalView)

        // Set up delegate
        terminalView.processDelegate = context.coordinator

        // Build environment as array of KEY=VALUE strings
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        for (key, value) in environment {
            env[key] = value
        }
        let envStrings = env.map { "\($0.key)=\($0.value)" }

        // Start the process
        let shell = command.isEmpty ? (env["SHELL"] ?? "/bin/zsh") : command
        let executablePath = shell.hasPrefix("/") ? shell : "/usr/bin/env"
        let execArgs = shell.hasPrefix("/") ? arguments : [shell] + arguments

        terminalView.startProcess(
            executable: executablePath,
            args: execArgs,
            environment: envStrings,
            execName: shell
        )

        // Change to working directory
        let cdCommand = "cd \"\(workingDirectory.path)\" && clear\n"
        terminalView.send(txt: cdCommand)

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Handle updates if needed (e.g., working directory change)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configureAppearance(_ terminalView: LocalProcessTerminalView) {
        // Font
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Configure terminal options
        terminalView.optionAsMetaKey = true

        // Light theme: white background, black text
        terminalView.nativeBackgroundColor = .white
        terminalView.nativeForegroundColor = .black
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // Terminal size changed
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            // Title changed - could update window title
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // Working directory changed
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            // Process terminated
            // Could show a message or restart the shell
        }
    }
}

/// A view that hosts a terminal for running Claude CLI
struct ClaudeTerminalView: NSViewRepresentable {
    let workingDirectory: URL

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Configure appearance
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.optionAsMetaKey = true
        terminalView.processDelegate = context.coordinator

        // Light theme: white background, black text
        terminalView.nativeBackgroundColor = .white
        terminalView.nativeForegroundColor = .black

        // Build environment as array of KEY=VALUE strings
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        let envStrings = env.map { "\($0.key)=\($0.value)" }

        // Start claude via shell to ensure correct working directory
        // SwiftTerm doesn't support setting working directory on process start,
        // so we use a shell to cd first, then exec claude
        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-c", "cd \"\(workingDirectory.path)\" && exec claude"],
            environment: envStrings,
            execName: "claude"
        )

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            // Claude exited - could restart or show message
        }
    }
}

/// NSViewRepresentable that uses TerminalManager for persistent sessions.
/// Unlike ClaudeTerminalView, this retrieves cached terminals from the manager
/// rather than creating new ones, allowing sessions to persist across switches.
struct PersistentClaudeTerminalView: NSViewRepresentable {
    let workspaceId: UUID
    let workingDirectory: URL

    func makeNSView(context: Context) -> NSView {
        // Create a container view that will host the terminal
        let containerView = TerminalContainerView()
        containerView.autoresizesSubviews = true

        // Update the current workspace in the manager
        TerminalManager.shared.currentWorkspaceId = workspaceId

        // Get or create the terminal from the manager
        let terminalView = TerminalManager.shared.claudeTerminal(
            for: workspaceId,
            workingDirectory: workingDirectory
        )
        terminalView.processDelegate = context.coordinator

        // Add terminal as subview with autoresizing
        containerView.hostedTerminal = terminalView
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(terminalView)

        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: containerView.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let containerView = nsView as? TerminalContainerView else { return }

        // Update the current workspace in the manager
        TerminalManager.shared.currentWorkspaceId = workspaceId

        // Get the terminal for this workspace (may be the same or different)
        let terminalView = TerminalManager.shared.claudeTerminal(
            for: workspaceId,
            workingDirectory: workingDirectory
        )

        // If the terminal changed, swap it
        if containerView.hostedTerminal !== terminalView {
            containerView.hostedTerminal?.removeFromSuperview()
            containerView.hostedTerminal = terminalView
            terminalView.processDelegate = context.coordinator
            terminalView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(terminalView)

            NSLayoutConstraint.activate([
                terminalView.topAnchor.constraint(equalTo: containerView.topAnchor),
                terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
        }

        // Ensure terminal is properly sized
        terminalView.frame = containerView.bounds
        terminalView.needsLayout = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(workspaceId: workspaceId, workingDirectory: workingDirectory)
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let workspaceId: UUID
        let workingDirectory: URL

        init(workspaceId: UUID, workingDirectory: URL) {
            self.workspaceId = workspaceId
            self.workingDirectory = workingDirectory
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        @MainActor
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            // Auto-restart Claude when it exits
            TerminalManager.shared.restartClaude(for: workspaceId, workingDirectory: workingDirectory)
        }
    }
}

/// NSViewRepresentable for persistent additional terminals (non-Claude shells).
struct PersistentAdditionalTerminalView: NSViewRepresentable {
    let workspaceId: UUID
    let terminalId: UUID
    let workingDirectory: URL
    let command: String
    let arguments: [String]

    func makeNSView(context: Context) -> NSView {
        let containerView = TerminalContainerView()
        containerView.autoresizesSubviews = true

        let terminalView = TerminalManager.shared.additionalTerminal(
            for: workspaceId,
            terminalId: terminalId,
            workingDirectory: workingDirectory,
            command: command,
            arguments: arguments
        )
        terminalView.processDelegate = context.coordinator

        containerView.hostedTerminal = terminalView
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(terminalView)

        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: containerView.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let containerView = nsView as? TerminalContainerView else { return }

        let terminalView = TerminalManager.shared.additionalTerminal(
            for: workspaceId,
            terminalId: terminalId,
            workingDirectory: workingDirectory,
            command: command,
            arguments: arguments
        )

        if containerView.hostedTerminal !== terminalView {
            containerView.hostedTerminal?.removeFromSuperview()
            containerView.hostedTerminal = terminalView
            terminalView.processDelegate = context.coordinator
            terminalView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(terminalView)

            NSLayoutConstraint.activate([
                terminalView.topAnchor.constraint(equalTo: containerView.topAnchor),
                terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
        }

        terminalView.frame = containerView.bounds
        terminalView.needsLayout = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            // For additional terminals, don't auto-restart - user can close the tab
        }
    }
}

/// Container NSView that holds a terminal and tracks it for swapping.
private class TerminalContainerView: NSView {
    weak var hostedTerminal: LocalProcessTerminalView?
}

#Preview {
    TerminalHostView(
        workingDirectory: FileManager.default.homeDirectoryForCurrentUser
    )
    .frame(width: 800, height: 600)
}
