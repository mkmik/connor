import XCTest
@testable import Connor

final class GitServiceTests: XCTestCase {
    var gitService: GitService!

    override func setUp() {
        super.setUp()
        gitService = GitService()
    }

    override func tearDown() {
        gitService = nil
        super.tearDown()
    }

    func testIsGitRepositoryReturnsFalseForNonRepo() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = await gitService.isGitRepository(tempDir)
        XCTAssertFalse(result)
    }

    func testFileChangeStatusDisplayNames() {
        XCTAssertEqual(FileChangeStatus.added.displayName, "Added")
        XCTAssertEqual(FileChangeStatus.modified.displayName, "Modified")
        XCTAssertEqual(FileChangeStatus.deleted.displayName, "Deleted")
        XCTAssertEqual(FileChangeStatus.renamed.displayName, "Renamed")
        XCTAssertEqual(FileChangeStatus.untracked.displayName, "Untracked")
    }

    func testFileChangeStatusRawValues() {
        XCTAssertEqual(FileChangeStatus.added.rawValue, "A")
        XCTAssertEqual(FileChangeStatus.modified.rawValue, "M")
        XCTAssertEqual(FileChangeStatus.deleted.rawValue, "D")
        XCTAssertEqual(FileChangeStatus.renamed.rawValue, "R")
        XCTAssertEqual(FileChangeStatus.untracked.rawValue, "?")
    }

    func testGitStatusStagedAndUnstagedChanges() {
        let changes = [
            GitFileChange(path: "file1.txt", status: .added, staged: true),
            GitFileChange(path: "file2.txt", status: .modified, staged: true),
            GitFileChange(path: "file3.txt", status: .modified, staged: false),
            GitFileChange(path: "file4.txt", status: .untracked, staged: false),
        ]

        let status = GitStatus(
            branch: "main",
            upstream: "origin/main",
            ahead: 0,
            behind: 0,
            isClean: false,
            changes: changes
        )

        XCTAssertEqual(status.stagedChanges.count, 2)
        XCTAssertEqual(status.unstagedChanges.count, 2)
    }

    func testGitErrorDescriptions() {
        XCTAssertNotNil(GitError.notARepository.errorDescription)
        XCTAssertNotNil(GitError.worktreeCreationFailed("test").errorDescription)
        XCTAssertNotNil(GitError.worktreeRemovalFailed("test").errorDescription)
        XCTAssertNotNil(GitError.commandFailed("test").errorDescription)
        XCTAssertNotNil(GitError.branchAlreadyExists("main").errorDescription)
    }
}
