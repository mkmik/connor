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
    var claudeBinaryName: String
    var gitHostingConfig: GitHostingConfig
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
    var leftPaneWidth: CGFloat?
    var rightPaneWidth: CGFloat?

    // Font settings
    var monospaceFontSize: CGFloat
    var monospaceFontName: String?  // nil means system monospace

    // Explicit CodingKeys including legacy keys for migration
    enum CodingKeys: String, CodingKey {
        case connorRootDirectory
        case recentRepositories
        case maxRecentRepos
        case preferredEditor
        case theme
        case recentlyUsedCityNames
        case maxCityNameHistory
        case defaultShell
        case claudeBinaryName
        case gitHostingConfig
        case branchNamePrefix
        case lastSelectedWorkspaceId
        case customThemes
        case selectedThemeId
        case isLeftPaneVisible
        case isRightPaneVisible
        case isBottomPanelExpanded
        case bottomPanelHeight
        case leftPaneWidth
        case rightPaneWidth
        case monospaceFontSize
        case monospaceFontName
        // Legacy keys (read-only, for migration from old preferences)
        case gitlabURL
        case gitlabToken
    }

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
            claudeBinaryName: "claude",
            gitHostingConfig: GitHostingConfig(providerType: .gitlab, baseURL: nil, token: nil),
            branchNamePrefix: "connor",
            lastSelectedWorkspaceId: nil,
            customThemes: [],
            selectedThemeId: Theme.light.id,
            isLeftPaneVisible: true,
            isRightPaneVisible: true,
            isBottomPanelExpanded: false,
            bottomPanelHeight: nil,
            leftPaneWidth: nil,
            rightPaneWidth: nil,
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
        claudeBinaryName: String,
        gitHostingConfig: GitHostingConfig,
        branchNamePrefix: String,
        lastSelectedWorkspaceId: UUID?,
        customThemes: [Theme],
        selectedThemeId: UUID?,
        isLeftPaneVisible: Bool,
        isRightPaneVisible: Bool,
        isBottomPanelExpanded: Bool,
        bottomPanelHeight: CGFloat?,
        leftPaneWidth: CGFloat?,
        rightPaneWidth: CGFloat?,
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
        self.claudeBinaryName = claudeBinaryName
        self.gitHostingConfig = gitHostingConfig
        self.branchNamePrefix = branchNamePrefix
        self.lastSelectedWorkspaceId = lastSelectedWorkspaceId
        self.customThemes = customThemes
        self.selectedThemeId = selectedThemeId
        self.isLeftPaneVisible = isLeftPaneVisible
        self.isRightPaneVisible = isRightPaneVisible
        self.isBottomPanelExpanded = isBottomPanelExpanded
        self.bottomPanelHeight = bottomPanelHeight
        self.leftPaneWidth = leftPaneWidth
        self.rightPaneWidth = rightPaneWidth
        self.monospaceFontSize = monospaceFontSize
        self.monospaceFontName = monospaceFontName
    }

    // Custom decoder to handle migration from older preferences
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
        claudeBinaryName = try container.decodeIfPresent(String.self, forKey: .claudeBinaryName) ?? "claude"

        // Migration: try new gitHostingConfig first, fall back to legacy gitlabURL/gitlabToken
        if let config = try container.decodeIfPresent(GitHostingConfig.self, forKey: .gitHostingConfig) {
            gitHostingConfig = config
        } else {
            let legacyURL = try container.decodeIfPresent(URL.self, forKey: .gitlabURL)
            let legacyToken = try container.decodeIfPresent(String.self, forKey: .gitlabToken)
            gitHostingConfig = GitHostingConfig(
                providerType: .gitlab,
                baseURL: legacyURL,
                token: legacyToken
            )
        }

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
        leftPaneWidth = try container.decodeIfPresent(CGFloat.self, forKey: .leftPaneWidth)
        rightPaneWidth = try container.decodeIfPresent(CGFloat.self, forKey: .rightPaneWidth)

        // Font settings - default to 13pt system monospace if missing
        monospaceFontSize = try container.decodeIfPresent(CGFloat.self, forKey: .monospaceFontSize) ?? 13
        monospaceFontName = try container.decodeIfPresent(String.self, forKey: .monospaceFontName)
    }

    // Custom encoder to avoid writing legacy keys
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(connorRootDirectory, forKey: .connorRootDirectory)
        try container.encode(recentRepositories, forKey: .recentRepositories)
        try container.encode(maxRecentRepos, forKey: .maxRecentRepos)
        try container.encode(preferredEditor, forKey: .preferredEditor)
        try container.encode(theme, forKey: .theme)
        try container.encode(recentlyUsedCityNames, forKey: .recentlyUsedCityNames)
        try container.encode(maxCityNameHistory, forKey: .maxCityNameHistory)
        try container.encode(defaultShell, forKey: .defaultShell)
        try container.encode(claudeBinaryName, forKey: .claudeBinaryName)
        try container.encode(gitHostingConfig, forKey: .gitHostingConfig)
        try container.encode(branchNamePrefix, forKey: .branchNamePrefix)
        try container.encodeIfPresent(lastSelectedWorkspaceId, forKey: .lastSelectedWorkspaceId)
        try container.encode(customThemes, forKey: .customThemes)
        try container.encodeIfPresent(selectedThemeId, forKey: .selectedThemeId)
        try container.encode(isLeftPaneVisible, forKey: .isLeftPaneVisible)
        try container.encode(isRightPaneVisible, forKey: .isRightPaneVisible)
        try container.encode(isBottomPanelExpanded, forKey: .isBottomPanelExpanded)
        try container.encodeIfPresent(bottomPanelHeight, forKey: .bottomPanelHeight)
        try container.encodeIfPresent(leftPaneWidth, forKey: .leftPaneWidth)
        try container.encodeIfPresent(rightPaneWidth, forKey: .rightPaneWidth)
        try container.encode(monospaceFontSize, forKey: .monospaceFontSize)
        try container.encodeIfPresent(monospaceFontName, forKey: .monospaceFontName)
        // Note: gitlabURL and gitlabToken legacy keys are intentionally not written
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
