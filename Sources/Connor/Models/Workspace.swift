import Foundation

/// Represents a single repository within a workspace (multi-repo ready)
struct WorkspaceRepository: Identifiable, Codable, Hashable {
    let id: UUID
    var sourceRepoURL: URL
    var worktreePath: URL
    var branchName: String
    var isMainRepo: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceRepoURL: URL,
        worktreePath: URL,
        branchName: String,
        isMainRepo: Bool = true
    ) {
        self.id = id
        self.sourceRepoURL = sourceRepoURL
        self.worktreePath = worktreePath
        self.branchName = branchName
        self.isMainRepo = isMainRepo
        self.createdAt = Date()
    }
}

/// Represents a workspace containing one or more repositories
struct Workspace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var displayName: String?
    var repositories: [WorkspaceRepository]
    var claudeSessionId: UUID?
    var isActive: Bool
    var sortOrder: Int
    let createdAt: Date
    var lastAccessedAt: Date

    var effectiveSessionId: UUID {
        claudeSessionId ?? id
    }

    var primaryRepository: WorkspaceRepository? {
        repositories.first(where: { $0.isMainRepo }) ?? repositories.first
    }

    var currentBranch: String? {
        primaryRepository?.branchName
    }

    var rootPath: URL? {
        primaryRepository?.worktreePath
    }

    var effectiveName: String {
        displayName ?? name
    }

    init(
        id: UUID = UUID(),
        name: String,
        repository: WorkspaceRepository,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.displayName = nil
        self.repositories = [repository]
        self.isActive = false
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }
}

/// Tracks workspace navigation history for back/forward
struct WorkspaceNavigationHistory: Codable {
    private var history: [UUID] = []
    private var currentIndex: Int = -1

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < history.count - 1 }

    var currentWorkspaceId: UUID? {
        guard currentIndex >= 0, currentIndex < history.count else { return nil }
        return history[currentIndex]
    }

    mutating func push(_ workspaceId: UUID) {
        // Don't push if it's the same as current
        if currentWorkspaceId == workspaceId { return }

        // Remove forward history when pushing new item
        if currentIndex < history.count - 1 {
            history = Array(history.prefix(currentIndex + 1))
        }
        history.append(workspaceId)
        currentIndex = history.count - 1
    }

    mutating func goBack() -> UUID? {
        guard canGoBack else { return nil }
        currentIndex -= 1
        return history[currentIndex]
    }

    mutating func goForward() -> UUID? {
        guard canGoForward else { return nil }
        currentIndex += 1
        return history[currentIndex]
    }

    mutating func remove(_ workspaceId: UUID) {
        history.removeAll { $0 == workspaceId }
        currentIndex = min(currentIndex, history.count - 1)
    }
}
