import SwiftUI

struct OpenInMenuButton: View {
    @EnvironmentObject var appState: AppState

    private let workspaceManager = WorkspaceManager()

    var body: some View {
        Menu {
            ForEach(ExternalEditor.allCases) { editor in
                Button {
                    openInEditor(editor)
                } label: {
                    Label(editor.rawValue, systemImage: editor.systemImageName)
                }
            }
        } label: {
            Label("Open", systemImage: "arrow.up.forward.square")
        }
        .menuIndicator(.visible)
        .disabled(appState.selectedWorkspace == nil)
        .help("Open workspace in external editor")
    }

    private func openInEditor(_ editor: ExternalEditor) {
        guard let workspace = appState.selectedWorkspace else { return }

        do {
            try workspaceManager.openInEditor(workspace, editor: editor)
        } catch {
            print("Failed to open in \(editor.rawValue): \(error.localizedDescription)")
        }
    }
}

#Preview {
    OpenInMenuButton()
        .environmentObject(AppState())
        .padding()
}
