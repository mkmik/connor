import XCTest
@testable import Connor

final class WorkspaceTests: XCTestCase {

    func testWorkspaceInitialization() {
        let repo = WorkspaceRepository(
            sourceRepoURL: URL(fileURLWithPath: "/tmp/source"),
            worktreePath: URL(fileURLWithPath: "/tmp/workspace"),
            branchName: "connor/tokyo"
        )

        let workspace = Workspace(name: "Tokyo", repository: repo)

        XCTAssertEqual(workspace.name, "Tokyo")
        XCTAssertEqual(workspace.effectiveName, "Tokyo")
        XCTAssertNil(workspace.displayName)
        XCTAssertEqual(workspace.repositories.count, 1)
        XCTAssertEqual(workspace.currentBranch, "connor/tokyo")
        XCTAssertEqual(workspace.rootPath, URL(fileURLWithPath: "/tmp/workspace"))
    }

    func testWorkspaceWithDisplayName() {
        let repo = WorkspaceRepository(
            sourceRepoURL: URL(fileURLWithPath: "/tmp/source"),
            worktreePath: URL(fileURLWithPath: "/tmp/workspace"),
            branchName: "connor/tokyo"
        )

        var workspace = Workspace(name: "Tokyo", repository: repo)
        workspace.displayName = "My Project"

        XCTAssertEqual(workspace.name, "Tokyo")
        XCTAssertEqual(workspace.displayName, "My Project")
        XCTAssertEqual(workspace.effectiveName, "My Project")
    }

    func testWorkspacePrimaryRepository() {
        let repo1 = WorkspaceRepository(
            sourceRepoURL: URL(fileURLWithPath: "/tmp/source1"),
            worktreePath: URL(fileURLWithPath: "/tmp/workspace1"),
            branchName: "connor/tokyo",
            isMainRepo: false
        )

        let repo2 = WorkspaceRepository(
            sourceRepoURL: URL(fileURLWithPath: "/tmp/source2"),
            worktreePath: URL(fileURLWithPath: "/tmp/workspace2"),
            branchName: "connor/tokyo-2",
            isMainRepo: true
        )

        var workspace = Workspace(name: "Tokyo", repository: repo1)
        workspace.repositories.append(repo2)

        // Primary repo should be the one marked as main
        XCTAssertEqual(workspace.primaryRepository?.id, repo2.id)
    }
}

final class WorkspaceNavigationHistoryTests: XCTestCase {

    func testEmptyHistory() {
        let history = WorkspaceNavigationHistory()

        XCTAssertFalse(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
        XCTAssertNil(history.currentWorkspaceId)
    }

    func testPushAddsToHistory() {
        var history = WorkspaceNavigationHistory()
        let id1 = UUID()
        let id2 = UUID()

        history.push(id1)
        XCTAssertEqual(history.currentWorkspaceId, id1)
        XCTAssertFalse(history.canGoBack)
        XCTAssertFalse(history.canGoForward)

        history.push(id2)
        XCTAssertEqual(history.currentWorkspaceId, id2)
        XCTAssertTrue(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
    }

    func testGoBackAndForward() {
        var history = WorkspaceNavigationHistory()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        history.push(id1)
        history.push(id2)
        history.push(id3)

        // Go back
        let backId = history.goBack()
        XCTAssertEqual(backId, id2)
        XCTAssertEqual(history.currentWorkspaceId, id2)
        XCTAssertTrue(history.canGoBack)
        XCTAssertTrue(history.canGoForward)

        // Go forward
        let forwardId = history.goForward()
        XCTAssertEqual(forwardId, id3)
        XCTAssertEqual(history.currentWorkspaceId, id3)
    }

    func testPushClearsForwardHistory() {
        var history = WorkspaceNavigationHistory()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        let id4 = UUID()

        history.push(id1)
        history.push(id2)
        history.push(id3)

        // Go back
        _ = history.goBack()
        XCTAssertTrue(history.canGoForward)

        // Push new item should clear forward history
        history.push(id4)
        XCTAssertFalse(history.canGoForward)
        XCTAssertEqual(history.currentWorkspaceId, id4)
    }

    func testPushSameIdDoesNotDuplicate() {
        var history = WorkspaceNavigationHistory()
        let id1 = UUID()

        history.push(id1)
        history.push(id1)
        history.push(id1)

        XCTAssertFalse(history.canGoBack)
        XCTAssertEqual(history.currentWorkspaceId, id1)
    }

    func testRemoveFromHistory() {
        var history = WorkspaceNavigationHistory()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        history.push(id1)
        history.push(id2)
        history.push(id3)

        history.remove(id2)

        // Should still be able to navigate, but id2 is gone
        _ = history.goBack()
        XCTAssertEqual(history.currentWorkspaceId, id1)
    }
}

// MARK: - Mock GitService for WorkspaceManager tests

final class MockGitService: GitServiceProtocol {
    var isGitRepositoryResult = true
    var hasRemoteResult = false
    var fetchShouldThrow = false
    var fetchCalled = false
    var lastCreateWorktreeStartPoint: String? = "NOT_CALLED"

    func isGitRepository(_ path: URL) async -> Bool { isGitRepositoryResult }

    func hasRemote(_ name: String, at path: URL) async throws -> Bool { hasRemoteResult }

    func fetch(remote: String, at path: URL) async throws {
        fetchCalled = true
        if fetchShouldThrow {
            throw GitError.commandFailed("fetch failed")
        }
    }

    func createWorktree(from sourceRepo: URL, at path: URL, branch: String, startPoint: String?) async throws {
        lastCreateWorktreeStartPoint = startPoint
    }

    func removeWorktree(at path: URL, sourceRepo: URL) async throws {}
    func pruneWorktrees(sourceRepo: URL) async throws {}
    func getCurrentBranch(at path: URL) async throws -> String { "main" }
    func getStatus(at path: URL) async throws -> GitStatus {
        GitStatus(branch: "main", upstream: nil, ahead: 0, behind: 0, isClean: true, changes: [])
    }
    func getDiffStats(at path: URL) async throws -> GitDiffStats { .empty }
}

final class MockCityNameGenerator: CityNameGeneratorProtocol {
    var allCityNames: [String] { ["TestCity"] }
    func generateUniqueName(excluding recentlyUsed: [String], existingNames: [String]) -> String {
        "TestCity"
    }
}

// MARK: - WorkspaceManager Tests

final class WorkspaceManagerTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private func makePreferences() -> Preferences {
        var prefs = Preferences.default
        prefs.connorRootDirectory = tempDir
        prefs.branchNamePrefix = "test"
        return prefs
    }

    func testCreateWorkspaceWithOriginFetchesAndBranchesFromRemote() async throws {
        let mockGit = MockGitService()
        mockGit.hasRemoteResult = true

        let manager = WorkspaceManager(
            gitService: mockGit,
            cityNameGenerator: MockCityNameGenerator()
        )

        // Create a fake source repo directory so fileManager.fileExists passes
        let sourceRepo = tempDir.appendingPathComponent("source-repo")
        try FileManager.default.createDirectory(at: sourceRepo, withIntermediateDirectories: true)

        _ = try await manager.createWorkspace(from: sourceRepo, preferences: makePreferences())

        XCTAssertTrue(mockGit.fetchCalled)
        XCTAssertEqual(mockGit.lastCreateWorktreeStartPoint, "origin/main")
    }

    func testCreateWorkspaceWithoutOriginDoesNotFetch() async throws {
        let mockGit = MockGitService()
        mockGit.hasRemoteResult = false

        let manager = WorkspaceManager(
            gitService: mockGit,
            cityNameGenerator: MockCityNameGenerator()
        )

        let sourceRepo = tempDir.appendingPathComponent("source-repo")
        try FileManager.default.createDirectory(at: sourceRepo, withIntermediateDirectories: true)

        _ = try await manager.createWorkspace(from: sourceRepo, preferences: makePreferences())

        XCTAssertFalse(mockGit.fetchCalled)
        XCTAssertNil(mockGit.lastCreateWorktreeStartPoint)
    }

    func testCreateWorkspaceFetchFailureStillUsesOriginMain() async throws {
        let mockGit = MockGitService()
        mockGit.hasRemoteResult = true
        mockGit.fetchShouldThrow = true

        let manager = WorkspaceManager(
            gitService: mockGit,
            cityNameGenerator: MockCityNameGenerator()
        )

        let sourceRepo = tempDir.appendingPathComponent("source-repo")
        try FileManager.default.createDirectory(at: sourceRepo, withIntermediateDirectories: true)

        // Should not throw despite fetch failure
        _ = try await manager.createWorkspace(from: sourceRepo, preferences: makePreferences())

        XCTAssertTrue(mockGit.fetchCalled)
        // Still uses origin/main even if fetch failed (stale refs are better than HEAD)
        XCTAssertEqual(mockGit.lastCreateWorktreeStartPoint, "origin/main")
    }
}

final class PreferencesTests: XCTestCase {

    func testDefaultPreferences() {
        let prefs = Preferences.default

        XCTAssertTrue(prefs.connorRootDirectory.path.contains(".connor"))
        XCTAssertTrue(prefs.recentRepositories.isEmpty)
        XCTAssertEqual(prefs.maxRecentRepos, 10)
        XCTAssertEqual(prefs.preferredEditor, .cursor)
        XCTAssertEqual(prefs.theme, .system)
        XCTAssertEqual(prefs.branchNamePrefix, "connor")
    }

    func testAddRecentRepository() {
        var prefs = Preferences.default
        let url1 = URL(fileURLWithPath: "/repo1")
        let url2 = URL(fileURLWithPath: "/repo2")

        prefs.addRecentRepository(url1)
        XCTAssertEqual(prefs.recentRepositories.count, 1)
        XCTAssertEqual(prefs.recentRepositories.first, url1)

        prefs.addRecentRepository(url2)
        XCTAssertEqual(prefs.recentRepositories.count, 2)
        XCTAssertEqual(prefs.recentRepositories.first, url2)  // Most recent first
    }

    func testAddRecentRepositoryDeduplicates() {
        var prefs = Preferences.default
        let url1 = URL(fileURLWithPath: "/repo1")

        prefs.addRecentRepository(url1)
        prefs.addRecentRepository(url1)

        XCTAssertEqual(prefs.recentRepositories.count, 1)
    }

    func testAddRecentRepositoryLimitsCount() {
        var prefs = Preferences.default
        prefs.maxRecentRepos = 3

        for i in 0..<5 {
            prefs.addRecentRepository(URL(fileURLWithPath: "/repo\(i)"))
        }

        XCTAssertEqual(prefs.recentRepositories.count, 3)
    }

    func testAddUsedCityName() {
        var prefs = Preferences.default

        prefs.addUsedCityName("Tokyo")
        prefs.addUsedCityName("Paris")

        XCTAssertEqual(prefs.recentlyUsedCityNames.count, 2)
        XCTAssertEqual(prefs.recentlyUsedCityNames.first, "Paris")  // Most recent first
    }
}
