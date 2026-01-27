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

final class PreferencesTests: XCTestCase {

    func testDefaultPreferences() {
        let prefs = Preferences.default

        XCTAssertTrue(prefs.connorRootDirectory.path.contains(".connor"))
        XCTAssertTrue(prefs.recentRepositories.isEmpty)
        XCTAssertEqual(prefs.maxRecentRepos, 10)
        XCTAssertEqual(prefs.preferredEditor, .cursor)
        XCTAssertEqual(prefs.theme, .system)
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
