import Foundation

/// Identifies which git hosting provider is active
enum GitHostingProviderType: String, Codable, CaseIterable, Identifiable {
    case gitlab = "GitLab"
    case github = "GitHub"

    var id: String { rawValue }

    /// Display name for code reviews: "Merge Request" vs "Pull Request"
    var codeReviewName: String {
        switch self {
        case .gitlab: return "Merge Request"
        case .github: return "Pull Request"
        }
    }

    /// Short abbreviation: "MR" vs "PR"
    var codeReviewAbbreviation: String {
        switch self {
        case .gitlab: return "MR"
        case .github: return "PR"
        }
    }

    /// Number prefix: "!" vs "#"
    var numberPrefix: String {
        switch self {
        case .gitlab: return "!"
        case .github: return "#"
        }
    }

    /// Help text for creating a personal access token
    var tokenHelpText: String {
        switch self {
        case .gitlab: return "Create a token with api scope in GitLab > Settings > Access Tokens"
        case .github: return "Create a personal access token at GitHub > Settings > Developer settings"
        }
    }

    /// Placeholder URL shown in the preferences text field
    var urlPlaceholder: String {
        switch self {
        case .gitlab: return "https://gitlab.example.com"
        case .github: return "https://github.com"
        }
    }
}

/// Configuration for a git hosting provider
struct GitHostingConfig: Codable, Equatable {
    var providerType: GitHostingProviderType
    var baseURL: URL?
    var token: String?

    var isConfigured: Bool {
        baseURL != nil && token != nil && !(token?.isEmpty ?? true)
    }
}

/// Errors from hosting provider operations
enum GitHostingError: Error, LocalizedError {
    case notConfigured
    case invalidRemoteURL
    case networkError(String)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Git hosting is not configured. Please set up your provider in Preferences."
        case .invalidRemoteURL:
            return "Could not parse project from git remote URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        }
    }
}

/// Protocol for git hosting provider services (GitLab, GitHub, etc.)
protocol GitHostingProvider {
    var providerType: GitHostingProviderType { get }

    /// Check if a code review exists for the given branch (open or merged)
    func findCodeReview(projectPath: String, branch: String) async throws -> CodeReview?

    /// Construct the URL for creating a new code review
    func newCodeReviewURL(baseURL: URL, projectPath: String, branch: String) -> URL?
}

// MARK: - Shared Default Implementations

extension GitHostingProvider {
    /// Gets the git remote URL for a repository (provider-agnostic)
    func getRemoteURL(at path: URL) async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["config", "--get", "remote.origin.url"]
        process.currentDirectoryURL = path

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return output?.isEmpty == true ? nil : output
    }

    /// Extracts the project path from a git remote URL (provider-agnostic)
    /// Handles both SSH and HTTPS URLs:
    /// - git@host:group/project.git -> group/project
    /// - https://host/group/project.git -> group/project
    func extractProjectPath(from remoteURL: String) -> String? {
        var url = remoteURL

        // Handle SSH format: git@host:group/project.git
        if url.hasPrefix("git@") {
            if let colonIndex = url.firstIndex(of: ":") {
                url = String(url[url.index(after: colonIndex)...])
            } else {
                return nil
            }
        }
        // Handle HTTPS format: https://host/group/project.git
        else if url.hasPrefix("https://") || url.hasPrefix("http://") {
            if let urlObj = URL(string: url) {
                url = urlObj.path
                if url.hasPrefix("/") {
                    url = String(url.dropFirst())
                }
            } else {
                return nil
            }
        }

        // Remove .git suffix
        if url.hasSuffix(".git") {
            url = String(url.dropLast(4))
        }

        return url.isEmpty ? nil : url
    }

    /// Workspace-aware code review lookup (provider-agnostic orchestration)
    func findCodeReview(for workspace: Workspace) async throws -> CodeReview? {
        guard let rootPath = workspace.rootPath,
              let branch = workspace.currentBranch else {
            return nil
        }

        guard let remoteURL = try await getRemoteURL(at: rootPath) else {
            print("[GitHostingProvider] Could not get remote URL for \(rootPath.path)")
            throw GitHostingError.invalidRemoteURL
        }

        print("[GitHostingProvider] Remote URL: '\(remoteURL)'")

        guard let projectPath = extractProjectPath(from: remoteURL) else {
            print("[GitHostingProvider] Could not extract project path from '\(remoteURL)'")
            throw GitHostingError.invalidRemoteURL
        }

        print("[GitHostingProvider] Extracted project path: '\(projectPath)'")

        return try await findCodeReview(projectPath: projectPath, branch: branch)
    }
}
