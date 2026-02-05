import SwiftUI

struct RightPane: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab: RightPaneTab = .files
    @State private var topPaneHeight: CGFloat = 400

    var selectedWorkspace: Workspace? {
        appState.selectedWorkspace
    }

    var sessionState: WorkspaceSessionState? {
        guard let id = appState.selectedWorkspaceId else { return nil }
        return appState.sessionState(for: id)
    }

    /// Background color for the current tab content
    var contentBackgroundColor: Color {
        switch selectedTab {
        case .files:
            return themeManager.currentTheme.rightFileManagerBackground.color
        case .changes:
            return themeManager.currentTheme.rightChangesBackground.color
        case .checks:
            return themeManager.currentTheme.rightChecksBackground.color
        }
    }

    var body: some View {
        VSplitView {
            // Top section - Files/Changes/Checks tabs
            VStack(spacing: 0) {
                Divider()
                .background(Color(nsColor: .windowBackgroundColor))

                // Tab bar
                HStack(spacing: 0) {
                    ForEach(RightPaneTab.allCases) { tab in
                        RightPaneTabButton(
                            tab: tab,
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(height: 36)
                .background(themeManager.currentTheme.rightToolbarBackground.color)

                Divider()

                // Tab content
                Group {
                    switch selectedTab {
                    case .files:
                        FileNavigatorView()
                    case .changes:
                        GitChangesView()
                    case .checks:
                        CIStatusView()
                    }
                }
            }
            .background(contentBackgroundColor)
            .frame(minHeight: 200)

            // Bottom section - Additional terminals
            if let session = sessionState, let workspace = selectedWorkspace {
                TerminalSection(session: session, workspace: workspace)
                    .frame(minHeight: 150)
            } else {
                VStack(spacing: 0) {
                    EmptyStateView(
                        icon: "terminal",
                        title: "No Workspace",
                        subtitle: "Select a workspace to use terminals"
                    )
                }
                .frame(minHeight: 150)
            }
        }
    }
}

/// Terminal section that properly observes WorkspaceSessionState changes
struct TerminalSection: View {
    @ObservedObject var session: WorkspaceSessionState
    @EnvironmentObject var themeManager: ThemeManager
    let workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            TerminalTabBar(
                terminals: $session.additionalTerminals,
                selectedTerminalId: $session.selectedTerminalId,
                onAddTerminal: {
                    if let path = workspace.rootPath {
                        _ = session.createTerminal(workingDirectory: path)
                    }
                },
                onCloseTerminal: { id in
                    session.closeTerminal(id)
                }
            )

            Divider()

            // Terminal content
            if let selectedTerminal = session.additionalTerminals.first(where: { $0.id == session.selectedTerminalId }),
               let workingDir = selectedTerminal.workingDirectory {
                PersistentAdditionalTerminalView(
                    workspaceId: workspace.id,
                    terminalId: selectedTerminal.id,
                    workingDirectory: workingDir,
                    command: selectedTerminal.command,
                    arguments: selectedTerminal.arguments,
                    onFocusGained: {
                        session.focusedTerminalArea = .additionalTerminal
                    },
                    shouldRestoreFocus: session.focusedTerminalArea == .additionalTerminal
                )
            } else if workspace.rootPath != nil {
                // Default terminal prompt view
                VStack {
                    Spacer()
                    Text("Click + to open a terminal")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.currentTheme.rightTerminalBackground.color)
            } else {
                EmptyStateView(
                    icon: "terminal",
                    title: "No Workspace",
                    subtitle: "Select a workspace to use terminals"
                )
            }
        }
    }
}

struct RightPaneTabButton: View {
    let tab: RightPaneTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(tab.rawValue)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    RightPane()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
        .frame(width: 350, height: 600)
}
