import SwiftUI

struct OpenInMenuButton: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false

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
            HStack(spacing: 4) {
                Text("Open")
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.secondary.opacity(0.15) : Color.clear)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { hovering in
            isHovering = hovering
        }
        .disabled(appState.selectedWorkspace == nil)
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
