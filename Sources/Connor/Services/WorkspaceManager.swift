import Foundation
import AppKit

/// Errors from workspace operations
enum WorkspaceError: Error, LocalizedError {
    case noRootPath
    case workspaceNotFound
    case sourceRepoNotFound
    case failedToCreateDirectory(String)
    case failedToOpenEditor(String)
    case worktrunkRemoveFailed(output: String)

    var errorDescription: String? {
        switch self {
        case .noRootPath:
            return "Workspace has no root path"
        case .workspaceNotFound:
            return "Workspace not found"
        case .sourceRepoNotFound:
            return "Source repository not found"
        case .failedToCreateDirectory(let message):
            return "Failed to create directory: \(message)"
        case .failedToOpenEditor(let message):
            return "Failed to open editor: \(message)"
        case .worktrunkRemoveFailed(let output):
            return "Worktrunk remove failed: \(output)"
        }
    }
}

/// Protocol for workspace management operations
protocol WorkspaceManagerProtocol {
    func createWorkspace(from sourceRepo: URL, preferences: Preferences) async throws -> Workspace
    func deleteWorkspace(_ workspace: Workspace, preferences: Preferences) async throws
    func forceDeleteWorktrunkWorkspace(_ workspace: Workspace, preferences: Preferences) async throws
    func openInEditor(_ workspace: Workspace, editor: ExternalEditor) throws
}

/// Implementation of workspace management
final class WorkspaceManager: WorkspaceManagerProtocol {
    private let gitService: GitServiceProtocol
    private let cityNameGenerator: CityNameGeneratorProtocol
    private let fileManager: FileManager

    init(
        gitService: GitServiceProtocol = GitService(),
        cityNameGenerator: CityNameGeneratorProtocol = CityNameGenerator(),
        fileManager: FileManager = .default
    ) {
        self.gitService = gitService
        self.cityNameGenerator = cityNameGenerator
        self.fileManager = fileManager
    }

    func createWorkspace(from sourceRepo: URL, preferences: Preferences) async throws -> Workspace {
        // Verify source repo exists and is a git repository
        guard fileManager.fileExists(atPath: sourceRepo.path) else {
            throw WorkspaceError.sourceRepoNotFound
        }

        guard await gitService.isGitRepository(sourceRepo) else {
            throw GitError.notARepository
        }

        // Get existing workspace names to avoid conflicts
        let existingNames = try getExistingWorkspaceNames(in: preferences.connorRootDirectory)

        // Generate unique city name
        let name = cityNameGenerator.generateUniqueName(
            excluding: preferences.recentlyUsedCityNames,
            existingNames: existingNames
        )

        // Create worktree dir name and branch name
        let worktreeDirName = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let branchName = "\(preferences.branchNamePrefix)/\(worktreeDirName)"

        let worktreePath: URL
        let useWorktrunk = preferences.useWorktrunk

        if useWorktrunk {
            // Use worktrunk to create the worktree
            let command = "wt -C \(shellEscape(sourceRepo.path)) switch -c \(shellEscape(branchName)) -x pwd"
            let result = try await runShellCommand(command, shell: preferences.defaultShell)
            guard result.exitCode == 0 else {
                let output = result.error.isEmpty ? result.output : result.error
                throw GitError.worktreeCreationFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                throw GitError.worktreeCreationFailed("wt returned empty worktree path")
            }
            worktreePath = URL(fileURLWithPath: path)
        } else {
            // Use git directly
            worktreePath = preferences.connorRootDirectory.appendingPathComponent(worktreeDirName)
            try await gitService.createWorktree(from: sourceRepo, at: worktreePath, branch: branchName)
        }

        // Create workspace model
        let repository = WorkspaceRepository(
            sourceRepoURL: sourceRepo,
            worktreePath: worktreePath,
            branchName: branchName,
            useWorktrunk: useWorktrunk
        )

        return Workspace(name: name, repository: repository)
    }

    func deleteWorkspace(_ workspace: Workspace, preferences: Preferences) async throws {
        guard let primaryRepo = workspace.primaryRepository else {
            throw WorkspaceError.noRootPath
        }

        let worktreePath = primaryRepo.worktreePath
        let sourceRepo = primaryRepo.sourceRepoURL

        if primaryRepo.useWorktrunk {
            // Use worktrunk to remove the worktree
            let command = "wt -C \(shellEscape(sourceRepo.path)) remove \(shellEscape(primaryRepo.branchName))"
            let result = try await runShellCommand(command, shell: preferences.defaultShell)
            guard result.exitCode == 0 else {
                let output = [result.output, result.error]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                throw WorkspaceError.worktrunkRemoveFailed(output: output)
            }
        } else {
            // 1. Pre-move prune: clean any stale git worktree refs
            try await gitService.removeWorktree(at: worktreePath, sourceRepo: sourceRepo)

            // 2. Move the worktree directory to the archive
            let archiveRoot = preferences.connorRootDirectory.appendingPathComponent(".archived")
            try fileManager.createDirectory(at: archiveRoot, withIntermediateDirectories: true)

            let dirName = worktreePath.lastPathComponent
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let archiveName = "\(dirName)-\(formatter.string(from: Date()))"
            let destination = archiveRoot.appendingPathComponent(archiveName)

            try fileManager.moveItem(at: worktreePath, to: destination)

            // 3. Post-move prune: cleans the now-stale worktree ref
            try await gitService.pruneWorktrees(sourceRepo: sourceRepo)
        }
    }

    func forceDeleteWorktrunkWorkspace(_ workspace: Workspace, preferences: Preferences) async throws {
        guard let primaryRepo = workspace.primaryRepository else {
            throw WorkspaceError.noRootPath
        }

        let command = "wt -C \(shellEscape(primaryRepo.sourceRepoURL.path)) remove -D \(shellEscape(primaryRepo.branchName))"
        let result = try await runShellCommand(command, shell: preferences.defaultShell)
        guard result.exitCode == 0 else {
            let output = [result.output, result.error]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw WorkspaceError.worktrunkRemoveFailed(output: output)
        }
    }

    func openInEditor(_ workspace: Workspace, editor: ExternalEditor) throws {
        guard let rootPath = workspace.rootPath else {
            throw WorkspaceError.noRootPath
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        // Get the app URL
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: editor.bundleIdentifier
        ) else {
            // Fallback: try to find the app in /Applications
            let appPath = "/Applications/\(editor.rawValue).app"
            if fileManager.fileExists(atPath: appPath) {
                NSWorkspace.shared.open(
                    [rootPath],
                    withApplicationAt: URL(fileURLWithPath: appPath),
                    configuration: configuration
                )
                return
            }
            throw WorkspaceError.failedToOpenEditor("Could not find \(editor.rawValue)")
        }

        NSWorkspace.shared.open(
            [rootPath],
            withApplicationAt: appURL,
            configuration: configuration
        )
    }

    // MARK: - Private Helpers

    private func runShellCommand(_ command: String, shell: String) async throws -> (output: String, error: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        return (output: output, error: error, exitCode: process.terminationStatus)
    }

    private func shellEscape(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func getExistingWorkspaceNames(in directory: URL) throws -> [String] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return contents.compactMap { url -> String? in
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return url.lastPathComponent
            }
            return nil
        }
    }
}
