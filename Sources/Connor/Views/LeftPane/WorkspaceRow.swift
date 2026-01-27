import SwiftUI

struct WorkspaceRow: View {
    let workspace: Workspace
    @EnvironmentObject var appState: AppState

    private var isSelected: Bool {
        appState.selectedWorkspaceId == workspace.id
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(workspace.isActive ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.effectiveName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let branch = workspace.currentBranch {
                    Text(branch)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open in Finder") {
                openInFinder()
            }

            Divider()

            Button("Rename...") {
                // TODO: Implement rename
            }

            Divider()

            Button("Delete", role: .destructive) {
                deleteWorkspace()
            }
        }
    }

    private func openInFinder() {
        guard let path = workspace.rootPath else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
    }

    private func deleteWorkspace() {
        Task {
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
}

#Preview {
    let repo = WorkspaceRepository(
        sourceRepoURL: URL(fileURLWithPath: "/tmp/repo"),
        worktreePath: URL(fileURLWithPath: "/tmp/tokyo"),
        branchName: "connor/tokyo"
    )
    let workspace = Workspace(name: "Tokyo", repository: repo)

    return WorkspaceRow(workspace: workspace)
        .environmentObject(AppState())
        .frame(width: 200)
        .padding()
}
