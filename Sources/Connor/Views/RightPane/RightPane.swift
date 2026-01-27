import SwiftUI

struct RightPane: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: RightPaneTab = .files
    @State private var topPaneHeight: CGFloat = 400

    var selectedWorkspace: Workspace? {
        appState.selectedWorkspace
    }

    var sessionState: WorkspaceSessionState? {
        guard let id = appState.selectedWorkspaceId else { return nil }
        return appState.sessionState(for: id)
    }

    var body: some View {
        VSplitView {
            // Top section - Files/Changes/Checks tabs
            VStack(spacing: 0) {
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
                .background(Color(nsColor: .controlBackgroundColor))

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
            .frame(minHeight: 200)

            // Bottom section - Additional terminals
            VStack(spacing: 0) {
                if let session = sessionState {
                    TerminalTabBar(
                        terminals: Binding(
                            get: { session.additionalTerminals },
                            set: { session.additionalTerminals = $0 }
                        ),
                        selectedTerminalId: Binding(
                            get: { session.selectedTerminalId },
                            set: { session.selectedTerminalId = $0 }
                        ),
                        onAddTerminal: {
                            if let path = selectedWorkspace?.rootPath {
                                _ = session.createTerminal(workingDirectory: path)
                            }
                        },
                        onCloseTerminal: { id in
                            session.closeTerminal(id)
                        }
                    )

                    Divider()

                    // Terminal content
                    if let workspace = selectedWorkspace,
                       let selectedTerminal = session.additionalTerminals.first(where: { $0.id == session.selectedTerminalId }),
                       let workingDir = selectedTerminal.workingDirectory {
                        PersistentAdditionalTerminalView(
                            workspaceId: workspace.id,
                            terminalId: selectedTerminal.id,
                            workingDirectory: workingDir,
                            command: selectedTerminal.command,
                            arguments: selectedTerminal.arguments
                        )
                    } else if selectedWorkspace?.rootPath != nil {
                        // Default terminal prompt view
                        VStack {
                            Spacer()
                            Text("Click + to open a terminal")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .textBackgroundColor))
                    } else {
                        EmptyStateView(
                            icon: "terminal",
                            title: "No Workspace",
                            subtitle: "Select a workspace to use terminals"
                        )
                    }
                } else {
                    EmptyStateView(
                        icon: "terminal",
                        title: "No Workspace",
                        subtitle: "Select a workspace to use terminals"
                    )
                }
            }
            .frame(minHeight: 150)
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
        .frame(width: 350, height: 600)
}
