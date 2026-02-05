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

    // Pane visibility state
    var isLeftPaneVisible: Bool
    var isRightPaneVisible: Bool
    var isBottomPanelExpanded: Bool
    var bottomPanelHeight: CGFloat?

    // Font settings
    var monospaceFontSize: CGFloat
    var monospaceFontName: String?  // nil means system monospace

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
            selectedThemeId: Theme.light.id,
            isLeftPaneVisible: true,
            isRightPaneVisible: true,
            isBottomPanelExpanded: false,
            bottomPanelHeight: nil,
            monospaceFontSize: 13,
            monospaceFontName: nil
        )
    }

    // Memberwise initializer (needed because custom decoder overrides synthesized init)
    init(
        connorRootDirectory: URL,
        recentRepositories: [URL],
        maxRecentRepos: Int,
        preferredEditor: ExternalEditor,
        theme: AppTheme,
        recentlyUsedCityNames: [String],
        maxCityNameHistory: Int,
        defaultShell: String,
        gitlabURL: URL?,
        gitlabToken: String?,
        branchNamePrefix: String,
        lastSelectedWorkspaceId: UUID?,
        customThemes: [Theme],
        selectedThemeId: UUID?,
        isLeftPaneVisible: Bool,
        isRightPaneVisible: Bool,
        isBottomPanelExpanded: Bool,
        bottomPanelHeight: CGFloat?,
        monospaceFontSize: CGFloat,
        monospaceFontName: String?
    ) {
        self.connorRootDirectory = connorRootDirectory
        self.recentRepositories = recentRepositories
        self.maxRecentRepos = maxRecentRepos
        self.preferredEditor = preferredEditor
        self.theme = theme
        self.recentlyUsedCityNames = recentlyUsedCityNames
        self.maxCityNameHistory = maxCityNameHistory
        self.defaultShell = defaultShell
        self.gitlabURL = gitlabURL
        self.gitlabToken = gitlabToken
        self.branchNamePrefix = branchNamePrefix
        self.lastSelectedWorkspaceId = lastSelectedWorkspaceId
        self.customThemes = customThemes
        self.selectedThemeId = selectedThemeId
        self.isLeftPaneVisible = isLeftPaneVisible
        self.isRightPaneVisible = isRightPaneVisible
        self.isBottomPanelExpanded = isBottomPanelExpanded
        self.bottomPanelHeight = bottomPanelHeight
        self.monospaceFontSize = monospaceFontSize
        self.monospaceFontName = monospaceFontName
    }

    // Custom decoder to handle migration from older preferences without theme fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        connorRootDirectory = try container.decode(URL.self, forKey: .connorRootDirectory)
        recentRepositories = try container.decode([URL].self, forKey: .recentRepositories)
        maxRecentRepos = try container.decode(Int.self, forKey: .maxRecentRepos)
        preferredEditor = try container.decode(ExternalEditor.self, forKey: .preferredEditor)
        theme = try container.decode(AppTheme.self, forKey: .theme)
        recentlyUsedCityNames = try container.decode([String].self, forKey: .recentlyUsedCityNames)
        maxCityNameHistory = try container.decode(Int.self, forKey: .maxCityNameHistory)
        defaultShell = try container.decode(String.self, forKey: .defaultShell)
        gitlabURL = try container.decodeIfPresent(URL.self, forKey: .gitlabURL)
        gitlabToken = try container.decodeIfPresent(String.self, forKey: .gitlabToken)
        branchNamePrefix = try container.decode(String.self, forKey: .branchNamePrefix)
        lastSelectedWorkspaceId = try container.decodeIfPresent(UUID.self, forKey: .lastSelectedWorkspaceId)

        // New theme properties - use defaults if missing (migration from older versions)
        customThemes = try container.decodeIfPresent([Theme].self, forKey: .customThemes) ?? []
        selectedThemeId = try container.decodeIfPresent(UUID.self, forKey: .selectedThemeId) ?? Theme.light.id

        // Pane visibility - default to visible if missing
        isLeftPaneVisible = try container.decodeIfPresent(Bool.self, forKey: .isLeftPaneVisible) ?? true
        isRightPaneVisible = try container.decodeIfPresent(Bool.self, forKey: .isRightPaneVisible) ?? true
        isBottomPanelExpanded = try container.decodeIfPresent(Bool.self, forKey: .isBottomPanelExpanded) ?? false
        bottomPanelHeight = try container.decodeIfPresent(CGFloat.self, forKey: .bottomPanelHeight)

        // Font settings - default to 13pt system monospace if missing
        monospaceFontSize = try container.decodeIfPresent(CGFloat.self, forKey: .monospaceFontSize) ?? 13
        monospaceFontName = try container.decodeIfPresent(String.self, forKey: .monospaceFontName)
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
