import Foundation

/// External editors/apps that can open workspaces
enum ExternalEditor: String, Codable, CaseIterable, Identifiable {
    case cursor = "Cursor"
    case zed = "Zed"
    case vscode = "VS Code"
    case iterm2 = "iTerm2"
    case terminal = "Terminal"
    case finder = "Finder"

    var id: String { rawValue }

    var bundleIdentifier: String {
        switch self {
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .zed: return "dev.zed.Zed"
        case .vscode: return "com.microsoft.VSCode"
        case .iterm2: return "com.googlecode.iterm2"
        case .terminal: return "com.apple.Terminal"
        case .finder: return "com.apple.finder"
        }
    }

    var systemImageName: String {
        switch self {
        case .cursor, .zed, .vscode: return "curlybraces"
        case .iterm2, .terminal: return "terminal"
        case .finder: return "folder"
        }
    }
}

/// Application theme
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }
}

/// User preferences stored in UserDefaults
struct Preferences: Codable, Equatable {
    var connorRootDirectory: URL
    var recentRepositories: [URL]
    var maxRecentRepos: Int
    var preferredEditor: ExternalEditor
    var theme: AppTheme
    var recentlyUsedCityNames: [String]
    var maxCityNameHistory: Int
    var defaultShell: String
    var gitlabURL: URL?
    var gitlabToken: String?
    var branchNamePrefix: String
    var lastSelectedWorkspaceId: UUID?

    // Theme system
    var customThemes: [Theme]
    var selectedThemeId: UUID?

    static var `default`: Preferences {
        Preferences(
            connorRootDirectory: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".connor"),
            recentRepositories: [],
            maxRecentRepos: 10,
            preferredEditor: .cursor,
            theme: .system,
            recentlyUsedCityNames: [],
            maxCityNameHistory: 50,
            defaultShell: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh",
            gitlabURL: nil,
            gitlabToken: nil,
            branchNamePrefix: "connor",
            lastSelectedWorkspaceId: nil,
            customThemes: [],
            selectedThemeId: Theme.light.id
        )
    }

    mutating func addRecentRepository(_ url: URL) {
        recentRepositories.removeAll { $0 == url }
        recentRepositories.insert(url, at: 0)
        if recentRepositories.count > maxRecentRepos {
            recentRepositories = Array(recentRepositories.prefix(maxRecentRepos))
        }
    }

    mutating func addUsedCityName(_ name: String) {
        recentlyUsedCityNames.removeAll { $0 == name }
        recentlyUsedCityNames.insert(name, at: 0)
        if recentlyUsedCityNames.count > maxCityNameHistory {
            recentlyUsedCityNames = Array(recentlyUsedCityNames.prefix(maxCityNameHistory))
        }
    }
}
