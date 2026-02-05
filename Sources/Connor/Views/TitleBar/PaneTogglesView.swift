import SwiftUI

/// VS Code/Cursor-style pane visibility toggle buttons
struct PaneTogglesView: View {
    var body: some View {
        HStack(spacing: 2) {
            PaneToggleButton(
                systemImage: "rectangle.lefthalf.inset.filled",
                tooltip: "Toggle Left Sidebar"
            ) {
                NSApp.sendAction(#selector(MainSplitViewController.toggleLeftSidebar(_:)), to: nil, from: nil)
            }

            PaneToggleButton(
                systemImage: "rectangle.bottomhalf.inset.filled",
                tooltip: "Toggle Bottom Panel"
            ) {
                // No-op for now
            }

            PaneToggleButton(
                systemImage: "rectangle.righthalf.inset.filled",
                tooltip: "Toggle Right Sidebar"
            ) {
                NSApp.sendAction(#selector(MainSplitViewController.toggleRightPane(_:)), to: nil, from: nil)
            }
        }
    }
}

struct PaneToggleButton: View {
    let systemImage: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}

#Preview {
    PaneTogglesView()
        .padding()
}
