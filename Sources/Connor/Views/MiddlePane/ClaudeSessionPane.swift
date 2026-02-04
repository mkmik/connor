import SwiftUI

struct ClaudeSessionPane: View {
    @EnvironmentObject var appState: AppState

    var sessionState: WorkspaceSessionState? {
        guard let id = appState.selectedWorkspaceId else { return nil }
        return appState.sessionState(for: id)
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            .background(Color(nsColor: .windowBackgroundColor))   
            
            // Tab bar
            if let session = sessionState {
                MiddlePaneTabBar(session: session)
            } else {
                // Fallback static tab bar when no workspace
                HStack(spacing: 0) {
                    MiddlePaneTabButton(
                        title: "Claude",
                        iconName: "sparkle",
                        isSelected: true,
                        isCloseable: false,
                        onSelect: {},
                        onClose: {}
                    )
                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(height: 36)
                .background(Color(nsColor: .controlBackgroundColor))
            }

            Divider()

            // Content
            if let workspace = appState.selectedWorkspace,
               let rootPath = workspace.rootPath,
               let session = sessionState {
                MiddlePaneContent(
                    session: session,
                    workspace: workspace,
                    rootPath: rootPath
                )
            } else {
                EmptyStateView(
                    icon: "terminal",
                    title: "No Workspace Selected",
                    subtitle: "Select or create a workspace to start a Claude session"
                )
            }
        }
    }
}

struct MiddlePaneTabBar: View {
    @ObservedObject var session: WorkspaceSessionState

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    // Claude tab (always first, not closeable)
                    MiddlePaneTabButton(
                        title: "Claude",
                        iconName: "sparkle",
                        isSelected: session.selectedMiddlePaneTab == .claude,
                        isCloseable: false,
                        onSelect: { session.selectTab(.claude) },
                        onClose: {}
                    )

                    // File tabs
                    ForEach(session.openFileTabs, id: \.self) { url in
                        MiddlePaneTabButton(
                            title: url.lastPathComponent,
                            iconName: MiddlePaneTab.file(url).iconName,
                            isSelected: session.selectedMiddlePaneTab == .file(url),
                            isCloseable: true,
                            onSelect: { session.selectTab(.file(url)) },
                            onClose: { session.closeFileTab(url) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()
        }
        .frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct MiddlePaneTabButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let isCloseable: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10))

            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)

            if isCloseable && (isHovering || isSelected) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.2))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundColor(isSelected ? .primary : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct MiddlePaneContent: View {
    @ObservedObject var session: WorkspaceSessionState
    let workspace: Workspace
    let rootPath: URL

    var body: some View {
        switch session.selectedMiddlePaneTab {
        case .claude:
            PersistentClaudeTerminalView(
                workspaceId: workspace.id,
                workingDirectory: rootPath,
                onFocusGained: {
                    session.focusedTerminalArea = .claude
                },
                shouldRestoreFocus: session.focusedTerminalArea == .claude
            )
        case .file(let url):
            FileViewerView(fileURL: url)
        }
    }
}

#Preview {
    ClaudeSessionPane()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
