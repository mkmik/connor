import Foundation

/// Stub service for GitHub API integration (not yet implemented)
final class GitHubProvider: GitHostingProvider {
    let providerType: GitHostingProviderType = .github
    private let config: () -> GitHostingConfig

    init(config: @escaping () -> GitHostingConfig) {
        self.config = config
    }

    func findCodeReview(projectPath: String, branch: String) async throws -> CodeReview? {
        // TODO: Implement GitHub API calls
        // GET /repos/{owner}/{repo}/pulls?head={owner}:{branch}&state=all
        return nil
    }

    func newCodeReviewURL(baseURL: URL, projectPath: String, branch: String) -> URL? {
        // GitHub format: {base}/{owner}/{repo}/compare/{branch}?expand=1
        let urlString = "\(baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/\(projectPath)/compare/\(branch)?expand=1"
        return URL(string: urlString)
    }
}
