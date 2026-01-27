import Foundation
import SwiftUI

/// Global application state
@MainActor
final class AppState: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceId: UUID?
    @Published var navigationHistory = WorkspaceNavigationHistory()
    @Published var preferences: Preferences = .default
    @Published var showNewWorkspaceSheet = false

    // Per-workspace session states (lazy, persists across workspace switches)
    @Published var sessionStates: [UUID: WorkspaceSessionState] = [:]

    private let preferencesService = PreferencesService()
    private let workspaceStorage = WorkspaceStorageService()

    var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceId }
    }

    var sortedWorkspaces: [Workspace] {
        workspaces.sorted { $0.sortOrder < $1.sortOrder }
    }

    var canNavigateBack: Bool {
        navigationHistory.canGoBack
    }

    var canNavigateForward: Bool {
        navigationHistory.canGoForward
    }

    init() {
        loadPreferences()
        loadWorkspaces()
    }

    func selectWorkspace(_ id: UUID?) {
        guard let id = id, id != selectedWorkspaceId else { return }
        selectedWorkspaceId = id
        navigationHistory.push(id)

        // Update last accessed time
        if let index = workspaces.firstIndex(where: { $0.id == id }) {
            workspaces[index].lastAccessedAt = Date()
            saveWorkspaces()
        }
    }

    func navigateBack() {
        if let id = navigationHistory.goBack() {
            selectedWorkspaceId = id
        }
    }

    func navigateForward() {
        if let id = navigationHistory.goForward() {
            selectedWorkspaceId = id
        }
    }

    func addWorkspace(_ workspace: Workspace) {
        var newWorkspace = workspace
        newWorkspace.sortOrder = workspaces.count
        workspaces.append(newWorkspace)

        // Add city name to recently used
        preferences.addUsedCityName(workspace.name)
        savePreferences()
        saveWorkspaces()

        selectWorkspace(newWorkspace.id)
    }

    func deleteWorkspace(_ workspace: Workspace) {
        workspaces.removeAll { $0.id == workspace.id }
        sessionStates.removeValue(forKey: workspace.id)
        navigationHistory.remove(workspace.id)

        // Select another workspace if the deleted one was selected
        if selectedWorkspaceId == workspace.id {
            selectedWorkspaceId = sortedWorkspaces.first?.id
        }

        // Reindex sort orders
        for (index, _) in workspaces.enumerated() {
            workspaces[index].sortOrder = index
        }

        saveWorkspaces()
    }

    func moveWorkspaces(from source: IndexSet, to destination: Int) {
        var sorted = sortedWorkspaces
        sorted.move(fromOffsets: source, toOffset: destination)

        // Update sort orders
        for (index, workspace) in sorted.enumerated() {
            if let workspaceIndex = workspaces.firstIndex(where: { $0.id == workspace.id }) {
                workspaces[workspaceIndex].sortOrder = index
            }
        }

        saveWorkspaces()
    }

    func sessionState(for workspaceId: UUID) -> WorkspaceSessionState {
        if let existing = sessionStates[workspaceId] {
            return existing
        }
        let newState = WorkspaceSessionState(workspaceId: workspaceId)
        sessionStates[workspaceId] = newState
        return newState
    }

    // MARK: - Persistence

    func loadPreferences() {
        preferences = preferencesService.load()
    }

    func savePreferences() {
        preferencesService.save(preferences)
    }

    func loadWorkspaces() {
        workspaces = workspaceStorage.load(rootDirectory: preferences.connorRootDirectory)
    }

    func saveWorkspaces() {
        workspaceStorage.save(workspaces, rootDirectory: preferences.connorRootDirectory)
    }
}

/// State for a single workspace's session
@MainActor
final class WorkspaceSessionState: ObservableObject, Identifiable {
    let id: UUID

    @Published var claudeTerminal: TerminalSessionState?
    @Published var additionalTerminals: [TerminalSessionState] = []
    @Published var selectedRightPaneTab: RightPaneTab = .files
    @Published var selectedTerminalId: UUID?

    init(workspaceId: UUID) {
        self.id = workspaceId
    }

    func createTerminal(workingDirectory: URL, title: String = "Terminal") -> TerminalSessionState {
        let terminal = TerminalSessionState(title: title, workingDirectory: workingDirectory)
        additionalTerminals.append(terminal)
        selectedTerminalId = terminal.id
        return terminal
    }

    func closeTerminal(_ id: UUID) {
        additionalTerminals.removeAll { $0.id == id }
        if selectedTerminalId == id {
            selectedTerminalId = additionalTerminals.last?.id
        }
    }
}

/// State for a terminal session
final class TerminalSessionState: ObservableObject, Identifiable, @unchecked Sendable {
    let id: UUID
    @Published var title: String
    @Published var isRunning: Bool
    let workingDirectory: URL?
    let command: String
    let arguments: [String]

    init(
        title: String = "Terminal",
        workingDirectory: URL? = nil,
        command: String? = nil,
        arguments: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.isRunning = false
        self.workingDirectory = workingDirectory
        self.command = command ?? (ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
        self.arguments = arguments
    }
}

/// Tabs in the right pane top section
enum RightPaneTab: String, CaseIterable, Identifiable {
    case files = "All files"
    case changes = "Changes"
    case checks = "Checks"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .files: return "folder"
        case .changes: return "arrow.triangle.branch"
        case .checks: return "checkmark.circle"
        }
    }
}
