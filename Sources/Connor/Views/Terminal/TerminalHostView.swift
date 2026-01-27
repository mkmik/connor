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

#Preview {
    TerminalHostView(
        workingDirectory: FileManager.default.homeDirectoryForCurrentUser
    )
    .frame(width: 800, height: 600)
}
