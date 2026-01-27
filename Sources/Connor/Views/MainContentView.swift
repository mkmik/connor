import SwiftUI

struct MainContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var leftPaneWidth: CGFloat = 220
    @State private var rightPaneWidth: CGFloat = 350

    var body: some View {
        VStack(spacing: 0) {
            // Custom title bar
            CustomTitleBar()
                .frame(height: 52)

            Divider()

            // Main three-pane layout
            HSplitView {
                // Left pane - Workspace list
                WorkspaceListPane()
                    .frame(minWidth: 180, idealWidth: leftPaneWidth, maxWidth: 300)

                // Middle pane - Claude session
                ClaudeSessionPane()
                    .frame(minWidth: 400)

                // Right pane - Files, changes, terminals
                RightPane()
                    .frame(minWidth: 280, idealWidth: rightPaneWidth, maxWidth: 500)
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
