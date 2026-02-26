import Foundation

// MARK: - Private GitLab API DTOs

/// GitLab pipeline JSON response
private struct GitLabPipelineDTO: Codable {
    let id: Int
    let status: String
    let webUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case webUrl = "web_url"
    }
}

/// GitLab merge request JSON response
private struct GitLabMergeRequestDTO: Codable {
    let id: Int
    let iid: Int
    let title: String
    let state: String
    let webUrl: String
    let headPipeline: GitLabPipelineDTO?

    enum CodingKeys: String, CodingKey {
        case id, iid, title, state
        case webUrl = "web_url"
        case headPipeline = "head_pipeline"
    }
}

// MARK: - GitLab Provider

/// Service for interacting with GitLab API
final class GitLabProvider: GitHostingProvider {
    let providerType: GitHostingProviderType = .gitlab
    private let config: () -> GitHostingConfig

    init(config: @escaping () -> GitHostingConfig) {
        self.config = config
    }

    func findCodeReview(projectPath: String, branch: String) async throws -> CodeReview? {
        // First check for open MRs, then fall back to merged MRs
        if let openMR = try await fetchMR(projectPath: projectPath, branch: branch, state: "opened") {
            return openMR
        }
        return try await fetchMR(projectPath: projectPath, branch: branch, state: "merged")
    }

    func newCodeReviewURL(baseURL: URL, projectPath: String, branch: String) -> URL? {
        let urlString = "\(baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/\(projectPath)/-/merge_requests/new?merge_request[source_branch]=\(branch)"
        return URL(string: urlString)
    }

    // MARK: - Private API Methods

    /// Fetches MRs for a given branch and state
    private func fetchMR(projectPath: String, branch: String, state: String) async throws -> CodeReview? {
        let cfg = config()

        guard let baseURL = cfg.baseURL, let token = cfg.token, !token.isEmpty else {
            throw GitHostingError.notConfigured
        }

        // URL-encode the project path - GitLab requires "/" to be encoded as %2F
        var allowedChars = CharacterSet.alphanumerics
        allowedChars.insert(charactersIn: "-._~")  // RFC 3986 unreserved characters (excluding /)
        let encodedProject = projectPath.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? projectPath

        print("[GitLabProvider] Project path: '\(projectPath)' -> encoded: '\(encodedProject)'")

        // Build the API URL to search for MRs by source branch
        let apiURLString = "\(baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/api/v4/projects/\(encodedProject)/merge_requests"
        guard let apiURL = URL(string: apiURLString) else {
            throw GitHostingError.networkError("Failed to construct API URL")
        }

        print("[GitLabProvider] API URL: \(apiURL)")

        var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "source_branch", value: branch),
            URLQueryItem(name: "state", value: state),
        ]

        guard let url = components.url else {
            throw GitHostingError.networkError("Failed to construct API URL with query params")
        }

        print("[GitLabProvider] Final URL with params: \(url)")

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHostingError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHostingError.apiError(httpResponse.statusCode, message)
        }

        let decoder = JSONDecoder()
        let mergeRequests = try decoder.decode([GitLabMergeRequestDTO].self, from: data)

        // The list endpoint may not include full pipeline data, so fetch the specific MR
        guard let mr = mergeRequests.first else {
            return nil
        }

        return try await fetchSingleMR(projectPath: projectPath, iid: mr.iid)
    }

    /// Fetches a single MR by IID to get full details including pipeline
    private func fetchSingleMR(projectPath: String, iid: Int) async throws -> CodeReview? {
        let cfg = config()

        guard let baseURL = cfg.baseURL, let token = cfg.token, !token.isEmpty else {
            throw GitHostingError.notConfigured
        }

        var allowedChars = CharacterSet.alphanumerics
        allowedChars.insert(charactersIn: "-._~")
        let encodedProject = projectPath.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? projectPath

        let apiURLString = "\(baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/api/v4/projects/\(encodedProject)/merge_requests/\(iid)"
        guard let url = URL(string: apiURLString) else {
            throw GitHostingError.networkError("Failed to construct single MR API URL")
        }

        print("[GitLabProvider] Fetching single MR: \(url)")

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHostingError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHostingError.apiError(httpResponse.statusCode, message)
        }

        let decoder = JSONDecoder()
        let dto = try decoder.decode(GitLabMergeRequestDTO.self, from: data)

        print("[GitLabProvider] Fetched MR \(dto.iid), pipeline: \(dto.headPipeline?.status ?? "none")")

        return dto.toCodeReview()
    }
}

// MARK: - DTO Mapping

private extension GitLabPipelineDTO {
    func toCIPipeline() -> CIPipeline {
        CIPipeline(
            id: id,
            status: CIPipelineStatus.from(gitlabStatus: status),
            webUrl: webUrl
        )
    }
}

private extension GitLabMergeRequestDTO {
    func toCodeReview() -> CodeReview {
        let reviewState: CodeReviewState
        switch state {
        case "merged": reviewState = .merged
        case "closed": reviewState = .closed
        default: reviewState = .open
        }

        return CodeReview(
            id: id,
            number: iid,
            title: title,
            state: reviewState,
            webUrl: webUrl,
            pipeline: headPipeline?.toCIPipeline()
        )
    }
}

private extension CIPipelineStatus {
    static func from(gitlabStatus: String) -> CIPipelineStatus {
        switch gitlabStatus {
        case "success": return .success
        case "running": return .running
        case "pending": return .pending
        case "failed": return .failed
        case "canceled": return .canceled
        case "skipped": return .skipped
        case "manual": return .manual
        case "created": return .created
        case "waiting_for_resource": return .waiting
        case "preparing": return .preparing
        default: return .unknown(gitlabStatus)
        }
    }
}
