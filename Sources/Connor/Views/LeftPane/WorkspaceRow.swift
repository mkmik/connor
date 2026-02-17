import SwiftUI

struct WorkspaceRow: View {
    let workspace: Workspace
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false

    private var isSelected: Bool {
        appState.selectedWorkspaceId == workspace.id
    }

    private var diffStats: GitDiffStats? {
        appState.diffStats(for: workspace.id)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Branch icon (always visible)
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                if let branch = workspace.currentBranch {
                    Text(branch)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Text(workspace.effectiveName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("·")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(timeAgo(from: workspace.lastAccessedAt))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)

            // Diff stats (if there are changes)
            if let stats = diffStats, stats.hasChanges {
                HStack(spacing: 2) {
                    Text("+\(stats.additions)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)

                    Text("-\(stats.deletions)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
            }
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

            Button("Close Session") {
                appState.resetClaudeSession(for: workspace.id)
            }

            Divider()

            Button("Rename...") {
                // TODO: Implement rename
            }

            Divider()

            Button("Delete", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .alert("Delete Workspace", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteWorkspace()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(workspace.effectiveName)\"? This will remove the worktree and cannot be undone.")
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

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    let repo = WorkspaceRepository(
        sourceRepoURL: URL(fileURLWithPath: "/tmp/repo"),
        worktreePath: URL(fileURLWithPath: "/tmp/tokyo"),
        branchName: "mkm/clean-terminal-start"
    )
    let workspace = Workspace(name: "abuja", repository: repo)

    return WorkspaceRow(workspace: workspace)
        .environmentObject(AppState())
        .frame(width: 280)
        .padding()
}
