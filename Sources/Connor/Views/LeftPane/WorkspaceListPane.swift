import SwiftUI

struct WorkspaceListPane: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var workspaceToDelete: Workspace?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Workspaces")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    appState.showNewWorkspaceSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Workspace")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Workspace list
            if appState.sortedWorkspaces.isEmpty {
                emptyState
            } else {
                workspaceList
            }
        }
        .background(themeManager.currentTheme.leftPaneBackground.color)
        .sheet(isPresented: $appState.showNewWorkspaceSheet) {
            NewWorkspaceSheet()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No workspaces")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text("Create a workspace to get started")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("New Workspace") {
                appState.showNewWorkspaceSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)

            Spacer()
        }
        .padding()
    }

    private var workspaceList: some View {
        List(selection: Binding(
            get: { appState.selectedWorkspaceId },
            set: { appState.selectWorkspace($0) }
        )) {
            ForEach(appState.sortedWorkspaces) { workspace in
                WorkspaceRow(workspace: workspace)
                    .tag(workspace.id)
            }
            .onMove { source, destination in
                appState.moveWorkspaces(from: source, to: destination)
            }
            .onDelete { indexSet in
                let sorted = appState.sortedWorkspaces
                if let index = indexSet.first {
                    workspaceToDelete = sorted[index]
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .alert("Delete Workspace", isPresented: Binding(
            get: { workspaceToDelete != nil },
            set: { if !$0 { workspaceToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let workspace = workspaceToDelete {
                    Task {
                        await deleteWorkspace(workspace)
                    }
                    workspaceToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                workspaceToDelete = nil
            }
        } message: {
            if let workspace = workspaceToDelete {
                Text("Are you sure you want to delete \"\(workspace.effectiveName)\"? This will remove the worktree and cannot be undone.")
            }
        }
    }

    private func deleteWorkspace(_ workspace: Workspace) async {
        let manager = WorkspaceManager()
        do {
            try await manager.deleteWorkspace(workspace)
            await MainActor.run {
                appState.deleteWorkspace(workspace)
            }
        } catch {
            print("Failed to delete workspace: \(error.localizedDescription)")
        }
    }
}

#Preview {
    WorkspaceListPane()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
        .frame(width: 220, height: 600)
}
