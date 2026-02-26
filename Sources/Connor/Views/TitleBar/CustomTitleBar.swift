import SwiftUI

struct CustomTitleBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Traffic light spacer (window buttons area)
            Color.clear
                .frame(width: 78)

            // Left section: Navigation buttons
            HStack(spacing: 4) {
                NavigationButton(direction: .back, enabled: appState.canNavigateBack) {
                    appState.navigateBack()
                }
                NavigationButton(direction: .forward, enabled: appState.canNavigateForward) {
                    appState.navigateForward()
                }

                Spacer()
            }
            .frame(width: 142)

            Divider()
                .frame(height: 24)

            // Middle section: Branch name
            HStack {
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
                Spacer()
            }
            .padding(.leading, 12)

            Divider()
                .frame(height: 24)

            // Right section: Create MR button and Open in menu
            HStack(spacing: 12) {
                Spacer()
                CreateCodeReviewButton()
                OpenInMenuButton()
            }
            .frame(width: 350)
            .padding(.trailing, 12)
        }
        .padding(.horizontal, 12)
    }
}

enum NavigationDirection {
    case back, forward

    var systemImageName: String {
        switch self {
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        }
    }
}

struct NavigationButton: View {
    let direction: NavigationDirection
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.systemImageName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(enabled ? .primary : .secondary.opacity(0.4))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

#Preview {
    CustomTitleBar()
        .environmentObject(AppState())
        .frame(height: 38)
        .frame(width: 1200)
}
