import AppKit
import SwiftUI

// MARK: - Toolbar Item Identifiers

extension NSToolbarItem.Identifier {
    static let sidebarTrackingSeparator = Self("sidebarTrackingSeparator")
    static let contentTrackingSeparator = Self("contentTrackingSeparator")
    static let branchDisplay = Self("branchDisplay")
    static let openInMenu = Self("openInMenu")
    static let createMR = Self("createMR")
    static let paneToggles = Self("paneToggles")
}

// MARK: - Generic Hosted Toolbar Item

/// Toolbar item that hosts a SwiftUI view
class HostedToolbarItem<Content: View>: NSToolbarItem {
    private let hostingView: NSHostingView<AnyView>

    init(_ identifier: NSToolbarItem.Identifier, view: Content) {
        let wrappedView = AnyView(view.environmentObject(AppState.shared))
        hostingView = NSHostingView(rootView: wrappedView)
        super.init(itemIdentifier: identifier)
        self.view = hostingView
    }
}

// MARK: - Branch Display Toolbar Item

/// Toolbar item showing the current branch name and diff stats
class BranchToolbarItem: NSToolbarItem {
    override init(itemIdentifier: NSToolbarItem.Identifier) {
        super.init(itemIdentifier: itemIdentifier)
        self.view = NSHostingView(rootView: BranchToolbarView())
    }
}

struct BranchToolbarView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        if let workspace = appState.selectedWorkspace,
           let branch = workspace.currentBranch {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12))
                Text(branch)
                    .font(.system(size: 13, weight: .medium))
                if let stats = appState.diffStats(for: workspace.id) {
                    Text("+\(stats.additions)/-\(stats.deletions)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.secondary)
        } else {
            Text("No workspace selected")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }
}
