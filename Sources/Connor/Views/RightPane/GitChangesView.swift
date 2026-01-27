import SwiftUI

struct GitChangesView: View {
    @EnvironmentObject var appState: AppState
    @State private var gitStatus: GitStatus?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let gitService = GitService()

    var rootPath: URL? {
        appState.selectedWorkspace?.rootPath
    }

    var body: some View {
        Group {
            if let root = rootPath {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            loadStatus(at: root)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let status = gitStatus {
                    if status.isClean {
                        EmptyStateView(
                            icon: "checkmark.circle",
                            title: "No Changes",
                            subtitle: "Working tree is clean"
                        )
                    } else {
                        changesList(status: status)
                    }
                } else {
                    EmptyStateView(
                        icon: "arrow.triangle.branch",
                        title: "Loading...",
                        subtitle: "Checking git status"
                    )
                }
            } else {
                EmptyStateView(
                    icon: "arrow.triangle.branch",
                    title: "No Workspace",
                    subtitle: "Select a workspace to view changes"
                )
            }
        }
        .onChange(of: rootPath) { newPath in
            if let path = newPath {
                loadStatus(at: path)
            } else {
                gitStatus = nil
            }
        }
        .onAppear {
            if let path = rootPath {
                loadStatus(at: path)
            }
        }
    }

    private func changesList(status: GitStatus) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Staged changes
                if !status.stagedChanges.isEmpty {
                    SectionHeader(title: "Staged Changes", count: status.stagedChanges.count)

                    ForEach(status.stagedChanges) { change in
                        GitChangeRow(change: change)
                    }
                }

                // Unstaged changes
                if !status.unstagedChanges.isEmpty {
                    SectionHeader(title: "Changes", count: status.unstagedChanges.count)

                    ForEach(status.unstagedChanges) { change in
                        GitChangeRow(change: change)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func loadStatus(at url: URL) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let status = try await gitService.getStatus(at: url)
                await MainActor.run {
                    self.gitStatus = status
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct GitChangeRow: View {
    let change: GitFileChange

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: change.status.systemImageName)
                .font(.system(size: 12))
                .foregroundColor(statusColor)
                .frame(width: 16)

            // File name
            Text(change.path)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // Status badge
            Text(change.status.rawValue)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(statusColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.15))
                .cornerRadius(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var statusColor: Color {
        switch change.status {
        case .added, .untracked: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .renamed, .copied: return .blue
        case .ignored: return .secondary
        }
    }
}

#Preview {
    GitChangesView()
        .environmentObject(AppState())
        .frame(width: 300, height: 400)
}
