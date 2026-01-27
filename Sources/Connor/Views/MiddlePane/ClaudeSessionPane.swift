import SwiftUI

struct ClaudeSessionPane: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (for future multi-tab support)
            HStack(spacing: 0) {
                TabButton(title: "Claude", isSelected: true) {}

                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Terminal content
            if let workspace = appState.selectedWorkspace,
               let rootPath = workspace.rootPath {
                ClaudeTerminalView(workingDirectory: rootPath)
                    .id(workspace.id)  // Force recreation when workspace changes
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

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10))

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    ClaudeSessionPane()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
