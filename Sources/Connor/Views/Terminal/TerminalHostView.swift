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

    func makeNSView(context: Context) -> NSView {
        let containerView = TerminalContainerView()
        containerView.autoresizesSubviews = true

        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Configure terminal appearance
        configureAppearance(terminalView)

        // Set up delegate
        terminalView.processDelegate = context.coordinator

        // Start the process via login shell + exec (clean startup without visible cd command)
        let env = ProcessInfo.processInfo.environment
        let shell = command.isEmpty ? (env["SHELL"] ?? "/bin/zsh") : command

        // Shell-escape arguments using single quotes
        let quotedArgs = arguments.map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let argsStr = quotedArgs.isEmpty ? "" : " " + quotedArgs.joined(separator: " ")

        terminalView.startLoginShell(
            workingDirectory: workingDirectory,
            command: "exec \(shell)\(argsStr)",
            extraEnvironment: environment,
            execName: shell
        )

        containerView.hostedTerminal = terminalView
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(terminalView)

        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: containerView.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
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

    func makeNSView(context: Context) -> NSView {
        let containerView = TerminalContainerView()
        containerView.autoresizesSubviews = true

        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Configure appearance
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.optionAsMetaKey = true
        terminalView.processDelegate = context.coordinator

        // Light theme: white background, black text
        terminalView.nativeBackgroundColor = .white
        terminalView.nativeForegroundColor = .black

        // Start claude via login shell to ensure correct working directory and PATH
        terminalView.startLoginShell(
            workingDirectory: workingDirectory,
            command: "exec claude",
            execName: "claude"
        )

        containerView.hostedTerminal = terminalView
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(terminalView)

        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: containerView.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

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
    var onFocusGained: (() -> Void)?
    var shouldRestoreFocus: Bool = false

    func makeNSView(context: Context) -> NSView {
        // Create a container view that will host the terminal
        let containerView = TerminalContainerView()
        containerView.autoresizesSubviews = true
        containerView.onFocusGained = onFocusGained

        // Set container background to match terminal
        let theme = ThemeManager.shared.currentTheme
        containerView.backgroundColor = theme.centralTerminalBackground.nsColor

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

        let padding: CGFloat = 8
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding),
            terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding)
        ])

        // Restore focus if needed
        if shouldRestoreFocus {
            DispatchQueue.main.async {
                terminalView.window?.makeFirstResponder(terminalView)
            }
        }

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let containerView = nsView as? TerminalContainerView else { return }

        // Update focus callback
        containerView.onFocusGained = onFocusGained

        // Update container background to match current theme
        let theme = ThemeManager.shared.currentTheme
        containerView.backgroundColor = theme.centralTerminalBackground.nsColor

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

            let padding: CGFloat = 8
            NSLayoutConstraint.activate([
                terminalView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
                terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding),
                terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
                terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding)
            ])

            // Restore focus if needed after swap
            if shouldRestoreFocus {
                DispatchQueue.main.async {
                    terminalView.window?.makeFirstResponder(terminalView)
                }
            }
        }

        // Request layout update on next run loop iteration to avoid
        // calling needsLayout during an active layout cycle
        DispatchQueue.main.async {
            terminalView.needsLayout = true
        }
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
    var onFocusGained: (() -> Void)?
    var shouldRestoreFocus: Bool = false

    func makeNSView(context: Context) -> NSView {
        let containerView = TerminalContainerView()
        containerView.autoresizesSubviews = true
        containerView.onFocusGained = onFocusGained

        // Set container background to match terminal
        let theme = ThemeManager.shared.currentTheme
        containerView.backgroundColor = theme.rightTerminalBackground.nsColor

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

        let padding: CGFloat = 8
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding),
            terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding)
        ])

        // Restore focus if needed
        if shouldRestoreFocus {
            DispatchQueue.main.async {
                terminalView.window?.makeFirstResponder(terminalView)
            }
        }

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let containerView = nsView as? TerminalContainerView else { return }

        // Update focus callback
        containerView.onFocusGained = onFocusGained

        // Update container background to match current theme
        let theme = ThemeManager.shared.currentTheme
        containerView.backgroundColor = theme.rightTerminalBackground.nsColor

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

            let padding: CGFloat = 8
            NSLayoutConstraint.activate([
                terminalView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
                terminalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding),
                terminalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
                terminalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding)
            ])

            // Restore focus if needed after swap
            if shouldRestoreFocus {
                DispatchQueue.main.async {
                    terminalView.window?.makeFirstResponder(terminalView)
                }
            }
        }

        // Request layout update on next run loop iteration to avoid
        // calling needsLayout during an active layout cycle
        DispatchQueue.main.async {
            terminalView.needsLayout = true
        }
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
    var onFocusGained: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        clipsToBounds = true
    }

    var backgroundColor: NSColor? {
        didSet {
            layer?.backgroundColor = backgroundColor?.cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        onFocusGained?()
        super.mouseDown(with: event)
    }
}

#Preview {
    TerminalHostView(
        workingDirectory: FileManager.default.homeDirectoryForCurrentUser
    )
    .frame(width: 800, height: 600)
}
