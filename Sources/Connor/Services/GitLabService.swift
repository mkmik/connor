import Foundation

/// Represents a GitLab pipeline status
struct GitLabPipeline: Codable {
    let id: Int
    let status: String
    let webUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case webUrl = "web_url"
    }
}

/// Represents a GitLab Merge Request
struct GitLabMergeRequest: Codable, Identifiable {
    let id: Int
    let iid: Int
    let title: String
    let state: String
    let webUrl: String
    let headPipeline: GitLabPipeline?

    enum CodingKeys: String, CodingKey {
        case id, iid, title, state
        case webUrl = "web_url"
        case headPipeline = "head_pipeline"
    }

    /// Whether this MR has been merged
    var isMerged: Bool {
        state == "merged"
    }

    /// Whether the pipeline completed successfully
    var hasPipelineSuccess: Bool {
        headPipeline?.status == "success"
    }

    /// Whether the pipeline is currently running
    var hasPipelineRunning: Bool {
        guard let status = headPipeline?.status else { return false }
        return status == "running" || status == "pending"
    }

    /// Whether the pipeline has failed
    var hasPipelineFailed: Bool {
        headPipeline?.status == "failed"
    }
}

/// Errors from GitLab operations
enum GitLabError: Error, LocalizedError {
    case notConfigured
    case invalidRemoteURL
    case networkError(String)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "GitLab is not configured. Please set up GitLab URL and token in Preferences."
        case .invalidRemoteURL:
            return "Could not parse GitLab project from git remote URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let code, let message):
            return "GitLab API error (\(code)): \(message)"
        }
    }
}

/// Service for interacting with GitLab API
final class GitLabService {
    private let preferences: () -> Preferences

    init(preferences: @escaping () -> Preferences) {
        self.preferences = preferences
    }

    /// Extracts the GitLab project path from a git remote URL
    /// Handles both SSH and HTTPS URLs:
    /// - git@gitlab.com:group/project.git -> group/project
    /// - https://gitlab.com/group/project.git -> group/project
    func extractProjectPath(from remoteURL: String) -> String? {
        var url = remoteURL

        // Handle SSH format: git@gitlab.com:group/project.git
        if url.hasPrefix("git@") {
            if let colonIndex = url.firstIndex(of: ":") {
                url = String(url[url.index(after: colonIndex)...])
            } else {
                return nil
            }
        }
        // Handle HTTPS format: https://gitlab.com/group/project.git
        else if url.hasPrefix("https://") || url.hasPrefix("http://") {
            if let urlObj = URL(string: url) {
                url = urlObj.path
                // Remove leading slash
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

    /// Gets the git remote URL for a repository (original config URL, without insteadOf expansion)
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

    /// Checks if an MR exists for the given branch (open or merged)
    func checkMRExists(projectPath: String, branch: String) async throws -> GitLabMergeRequest? {
        // First check for open MRs, then fall back to merged MRs
        if let openMR = try await fetchMR(projectPath: projectPath, branch: branch, state: "opened") {
            return openMR
        }
        return try await fetchMR(projectPath: projectPath, branch: branch, state: "merged")
    }

    /// Fetches MRs for a given branch and state
    private func fetchMR(projectPath: String, branch: String, state: String) async throws -> GitLabMergeRequest? {
        let prefs = preferences()

        guard let baseURL = prefs.gitlabURL, let token = prefs.gitlabToken, !token.isEmpty else {
            throw GitLabError.notConfigured
        }

        // URL-encode the project path - GitLab requires "/" to be encoded as %2F
        // .urlPathAllowed doesn't encode "/", so we need to use .alphanumerics and add safe chars
        var allowedChars = CharacterSet.alphanumerics
        allowedChars.insert(charactersIn: "-._~")  // RFC 3986 unreserved characters (excluding /)
        let encodedProject = projectPath.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? projectPath

        print("[GitLabService] Project path: '\(projectPath)' -> encoded: '\(encodedProject)'")

        // Build the API URL to search for MRs by source branch
        // Note: Don't use appendPathComponent for encodedProject as it will decode %2F
        let apiURLString = "\(baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/api/v4/projects/\(encodedProject)/merge_requests"
        guard let apiURL = URL(string: apiURLString) else {
            throw GitLabError.networkError("Failed to construct API URL")
        }

        print("[GitLabService] API URL: \(apiURL)")

        var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "source_branch", value: branch),
            URLQueryItem(name: "state", value: state),
        ]

        guard let url = components.url else {
            throw GitLabError.networkError("Failed to construct API URL with query params")
        }

        print("[GitLabService] Final URL with params: \(url)")

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitLabError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitLabError.apiError(httpResponse.statusCode, message)
        }

        let decoder = JSONDecoder()
        let mergeRequests = try decoder.decode([GitLabMergeRequest].self, from: data)

        // The list endpoint may not include full pipeline data, so fetch the specific MR
        guard let mr = mergeRequests.first else {
            return nil
        }

        return try await fetchSingleMR(projectPath: projectPath, iid: mr.iid)
    }

    /// Fetches a single MR by IID to get full details including pipeline
    private func fetchSingleMR(projectPath: String, iid: Int) async throws -> GitLabMergeRequest? {
        let prefs = preferences()

        guard let baseURL = prefs.gitlabURL, let token = prefs.gitlabToken, !token.isEmpty else {
            throw GitLabError.notConfigured
        }

        var allowedChars = CharacterSet.alphanumerics
        allowedChars.insert(charactersIn: "-._~")
        let encodedProject = projectPath.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? projectPath

        let apiURLString = "\(baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/api/v4/projects/\(encodedProject)/merge_requests/\(iid)"
        guard let url = URL(string: apiURLString) else {
            throw GitLabError.networkError("Failed to construct single MR API URL")
        }

        print("[GitLabService] Fetching single MR: \(url)")

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitLabError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitLabError.apiError(httpResponse.statusCode, message)
        }

        let decoder = JSONDecoder()
        let mr = try decoder.decode(GitLabMergeRequest.self, from: data)

        print("[GitLabService] Fetched MR \(mr.iid), pipeline: \(mr.headPipeline?.status ?? "none")")

        return mr
    }

    /// Checks if an MR exists for the current branch of a workspace
    func checkMRExists(for workspace: Workspace) async throws -> GitLabMergeRequest? {
        guard let rootPath = workspace.rootPath,
              let branch = workspace.currentBranch else {
            return nil
        }

        guard let remoteURL = try await getRemoteURL(at: rootPath) else {
            print("[GitLabService] Could not get remote URL for \(rootPath.path)")
            throw GitLabError.invalidRemoteURL
        }

        print("[GitLabService] Remote URL: '\(remoteURL)'")

        guard let projectPath = extractProjectPath(from: remoteURL) else {
            print("[GitLabService] Could not extract project path from '\(remoteURL)'")
            throw GitLabError.invalidRemoteURL
        }

        print("[GitLabService] Extracted project path: '\(projectPath)'")

        return try await checkMRExists(projectPath: projectPath, branch: branch)
    }
}
