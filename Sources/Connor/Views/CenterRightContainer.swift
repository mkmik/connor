import SwiftUI

/// Terminal section that can be shared between RightPane and the bottom panel.
/// Pulls workspace and session state from AppState.
struct SharedTerminalSection: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    /// Forces view recreation when the panel expands, fixing rendering issues
    /// that occur when NSSplitViewItem is collapsed and then expanded.
    @State private var refreshId = UUID()

    var selectedWorkspace: Workspace? {
        appState.selectedWorkspace
    }

    var sessionState: WorkspaceSessionState? {
        guard let id = appState.selectedWorkspaceId else { return nil }
        return appState.sessionState(for: id)
    }

    var isBottomPanelExpanded: Bool {
        appState.preferences.isBottomPanelExpanded
    }

    var body: some View {
        Group {
            if let session = sessionState, let workspace = selectedWorkspace {
                TerminalSection(session: session, workspace: workspace)
            } else {
                VStack(spacing: 0) {
                    EmptyStateView(
                        icon: "terminal",
                        title: "No Workspace",
                        subtitle: "Select a workspace to use terminals"
                    )
                }
            }
        }
        .id(refreshId)
        .onChange(of: isBottomPanelExpanded) { _, expanded in
            if expanded {
                // Force view recreation when panel expands to fix rendering issues
                refreshId = UUID()
            }
        }
    }
}
