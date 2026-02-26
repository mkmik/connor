import Foundation

/// Creates the appropriate hosting provider based on configuration
enum GitHostingProviderFactory {
    static func makeProvider(config: @escaping () -> GitHostingConfig) -> GitHostingProvider {
        let currentConfig = config()
        switch currentConfig.providerType {
        case .gitlab:
            return GitLabProvider(config: config)
        case .github:
            return GitHubProvider(config: config)
        }
    }
}
