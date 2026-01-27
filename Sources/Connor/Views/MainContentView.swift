import SwiftUI

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var rightPaneWidth: CGFloat = 350
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Workspace list
            WorkspaceListPane()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            // Middle pane - Claude session
            ClaudeSessionPane()
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        } detail: {
            // Right pane - Files, changes, terminals
            RightPane()
                .navigationSplitViewColumnWidth(min: 280, ideal: rightPaneWidth, max: 500)
        }
        .toolbar {
            // Left: Navigation buttons (near traffic lights)
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    appState.navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!appState.canNavigateBack)
                .help("Go Back (⌘[)")

                Button {
                    appState.navigateForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!appState.canNavigateForward)
                .help("Go Forward (⌘])")
            }

            // Center: Branch name
            ToolbarItem(placement: .principal) {
                if let workspace = appState.selectedWorkspace,
                   let branch = workspace.currentBranch {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 12))
                        Text(branch)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                } else {
                    Text("No workspace selected")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }

            // Right: Open in menu
            ToolbarItemGroup(placement: .primaryAction) {
                OpenInMenuButton()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $appState.showNewWorkspaceSheet) {
            NewWorkspaceSheet()
        }
    }
}

#Preview {
    MainContentView()
        .environmentObject(AppState())
        .frame(width: 1400, height: 900)
}
