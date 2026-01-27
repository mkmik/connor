import Foundation

/// Represents a changed file in git
struct GitFileChange: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let status: FileChangeStatus
    let staged: Bool
}

/// Status of a file change
enum FileChangeStatus: String, CaseIterable {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"

    var displayName: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        case .ignored: return "Ignored"
        }
    }

    var systemImageName: String {
        switch self {
        case .added: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .copied: return "doc.on.doc.fill"
        case .untracked: return "questionmark.circle.fill"
        case .ignored: return "eye.slash.circle.fill"
        }
    }
}

/// Git status summary
struct GitStatus {
    let branch: String
    let upstream: String?
    let ahead: Int
    let behind: Int
    let isClean: Bool
    let changes: [GitFileChange]

    var stagedChanges: [GitFileChange] {
        changes.filter { $0.staged }
    }

    var unstagedChanges: [GitFileChange] {
        changes.filter { !$0.staged }
    }
}

/// Errors from git operations
enum GitError: Error, LocalizedError {
    case notARepository
    case worktreeCreationFailed(String)
    case worktreeRemovalFailed(String)
    case commandFailed(String)
    case branchAlreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .notARepository:
            return "The specified path is not a git repository"
        case .worktreeCreationFailed(let message):
            return "Failed to create worktree: \(message)"
        case .worktreeRemovalFailed(let message):
            return "Failed to remove worktree: \(message)"
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        case .branchAlreadyExists(let branch):
            return "Branch '\(branch)' already exists"
        }
    }
}

/// Protocol for git operations
protocol GitServiceProtocol {
    func createWorktree(from sourceRepo: URL, at path: URL, branch: String) async throws
    func removeWorktree(at path: URL, sourceRepo: URL) async throws
    func getCurrentBranch(at path: URL) async throws -> String
    func getStatus(at path: URL) async throws -> GitStatus
    func isGitRepository(_ path: URL) async -> Bool
}

/// Implementation using git CLI
final class GitService: GitServiceProtocol {
    private let fileManager = FileManager.default

    func createWorktree(from sourceRepo: URL, at path: URL, branch: String) async throws {
        // First check if the branch already exists
        let branchExists = try await branchExists(branch, at: sourceRepo)

        var arguments: [String]
        if branchExists {
            // If branch exists, check it out in the worktree
            arguments = ["worktree", "add", path.path, branch]
        } else {
            // Create new branch
            arguments = ["worktree", "add", "-b", branch, path.path]
        }

        let result = try await runGitCommand(arguments, at: sourceRepo)

        if !result.success {
            throw GitError.worktreeCreationFailed(result.error)
        }
    }

    func removeWorktree(at path: URL, sourceRepo: URL) async throws {
        // First prune any stale worktrees
        _ = try? await runGitCommand(["worktree", "prune"], at: sourceRepo)

        // Remove the worktree
        let result = try await runGitCommand(["worktree", "remove", path.path, "--force"], at: sourceRepo)

        if !result.success {
            // Try removing the directory manually if git command fails
            try? fileManager.removeItem(at: path)
        }
    }

    func getCurrentBranch(at path: URL) async throws -> String {
        let result = try await runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"], at: path)

        if result.success {
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            throw GitError.commandFailed(result.error)
        }
    }

    func getStatus(at path: URL) async throws -> GitStatus {
        // Get branch info
        let branch = try await getCurrentBranch(at: path)

        // Get upstream tracking info
        let upstreamResult = try await runGitCommand(
            ["rev-parse", "--abbrev-ref", "@{upstream}"],
            at: path
        )
        let upstream = upstreamResult.success
            ? upstreamResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        // Get ahead/behind counts
        var ahead = 0
        var behind = 0
        if upstream != nil {
            let countResult = try await runGitCommand(
                ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"],
                at: path
            )
            if countResult.success {
                let parts = countResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                if parts.count >= 2 {
                    ahead = Int(parts[0]) ?? 0
                    behind = Int(parts[1]) ?? 0
                }
            }
        }

        // Get file changes with porcelain format
        let statusResult = try await runGitCommand(["status", "--porcelain=v1"], at: path)
        var changes: [GitFileChange] = []

        if statusResult.success {
            let lines = statusResult.output.components(separatedBy: .newlines)
            for line in lines where line.count >= 3 {
                let indexStatus = line[line.startIndex]
                let workTreeStatus = line[line.index(after: line.startIndex)]
                let filePath = String(line.dropFirst(3))

                // Determine if staged and the status
                if indexStatus != " " && indexStatus != "?" {
                    // Staged change
                    if let status = parseStatus(indexStatus) {
                        changes.append(GitFileChange(path: filePath, status: status, staged: true))
                    }
                }

                if workTreeStatus != " " {
                    // Unstaged change
                    let statusChar = workTreeStatus == "?" ? "?" : workTreeStatus
                    if let status = parseStatus(statusChar) {
                        changes.append(GitFileChange(path: filePath, status: status, staged: false))
                    }
                }
            }
        }

        return GitStatus(
            branch: branch,
            upstream: upstream,
            ahead: ahead,
            behind: behind,
            isClean: changes.isEmpty,
            changes: changes
        )
    }

    func isGitRepository(_ path: URL) async -> Bool {
        let result = try? await runGitCommand(["rev-parse", "--git-dir"], at: path)
        return result?.success ?? false
    }

    // MARK: - Private Helpers

    private func branchExists(_ branch: String, at path: URL) async throws -> Bool {
        let result = try await runGitCommand(
            ["show-ref", "--verify", "--quiet", "refs/heads/\(branch)"],
            at: path
        )
        return result.exitCode == 0
    }

    private func parseStatus(_ char: Character) -> FileChangeStatus? {
        switch char {
        case "A": return .added
        case "M": return .modified
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "?": return .untracked
        case "!": return .ignored
        default: return nil
        }
    }

    private struct CommandResult {
        let output: String
        let error: String
        let exitCode: Int32
        var success: Bool { exitCode == 0 }
    }

    private func runGitCommand(_ arguments: [String], at path: URL) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = path

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

        return CommandResult(output: output, error: error, exitCode: process.terminationStatus)
    }
}
