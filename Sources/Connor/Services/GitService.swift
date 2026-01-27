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

/// Git diff statistics (lines added/removed)
struct GitDiffStats: Equatable {
    let additions: Int
    let deletions: Int

    var hasChanges: Bool {
        additions > 0 || deletions > 0
    }

    static let empty = GitDiffStats(additions: 0, deletions: 0)
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
    func getDiffStats(at path: URL) async throws -> GitDiffStats
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

    func getDiffStats(at path: URL) async throws -> GitDiffStats {
        // Get diff stats comparing working tree to merge base with main/master
        // First try to find the merge base with origin/main or origin/master
        var baseBranch = "origin/main"

        // Check if origin/main exists, otherwise try origin/master
        let mainCheck = try await runGitCommand(["rev-parse", "--verify", "origin/main"], at: path)
        if !mainCheck.success {
            let masterCheck = try await runGitCommand(["rev-parse", "--verify", "origin/master"], at: path)
            if masterCheck.success {
                baseBranch = "origin/master"
            } else {
                // No remote tracking branch found, compare with HEAD
                return try await getDiffStatsFromWorkingTree(at: path)
            }
        }

        // Get merge base
        let mergeBaseResult = try await runGitCommand(["merge-base", baseBranch, "HEAD"], at: path)
        guard mergeBaseResult.success else {
            return try await getDiffStatsFromWorkingTree(at: path)
        }
        let mergeBase = mergeBaseResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Get diff stats from merge base to working tree (includes uncommitted changes)
        let result = try await runGitCommand(["diff", "--shortstat", mergeBase], at: path)

        var stats = GitDiffStats.empty
        if result.success {
            stats = parseDiffStats(result.output)
        }

        // Also count lines in untracked files
        let untrackedLines = try await countUntrackedFileLines(at: path)
        return GitDiffStats(additions: stats.additions + untrackedLines, deletions: stats.deletions)
    }

    private func getDiffStatsFromWorkingTree(at path: URL) async throws -> GitDiffStats {
        // Get stats for uncommitted changes only
        let result = try await runGitCommand(["diff", "--shortstat", "HEAD"], at: path)
        var stats = GitDiffStats.empty
        if result.success {
            stats = parseDiffStats(result.output)
        }

        // Also count lines in untracked files
        let untrackedLines = try await countUntrackedFileLines(at: path)
        return GitDiffStats(additions: stats.additions + untrackedLines, deletions: stats.deletions)
    }

    private func countUntrackedFileLines(at path: URL) async throws -> Int {
        // Get list of untracked files (excluding ignored)
        let result = try await runGitCommand(["ls-files", "--others", "--exclude-standard"], at: path)
        guard result.success else { return 0 }

        let files = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !files.isEmpty else { return 0 }

        // Count lines in all untracked files using wc -l
        var totalLines = 0
        for file in files {
            let filePath = path.appendingPathComponent(file)
            // Skip directories and binary files
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: filePath.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { continue }

            // Use wc -l to count lines
            let wcResult = try await runCommand("/usr/bin/wc", arguments: ["-l", filePath.path])
            if wcResult.success {
                // wc output is like "    42 /path/to/file"
                let trimmed = wcResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if let lineCount = trimmed.split(separator: " ").first, let count = Int(lineCount) {
                    totalLines += count
                }
            }
        }

        return totalLines
    }

    private func runCommand(_ executable: String, arguments: [String]) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

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

    private func parseDiffStats(_ output: String) -> GitDiffStats {
        // Parse output like: " 3 files changed, 14 insertions(+), 18 deletions(-)"
        var additions = 0
        var deletions = 0

        // Look for insertions
        if let insertRange = output.range(of: #"(\d+) insertion"#, options: .regularExpression) {
            let insertStr = output[insertRange]
            if let num = insertStr.split(separator: " ").first, let count = Int(num) {
                additions = count
            }
        }

        // Look for deletions
        if let deleteRange = output.range(of: #"(\d+) deletion"#, options: .regularExpression) {
            let deleteStr = output[deleteRange]
            if let num = deleteStr.split(separator: " ").first, let count = Int(num) {
                deletions = count
            }
        }

        return GitDiffStats(additions: additions, deletions: deletions)
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
