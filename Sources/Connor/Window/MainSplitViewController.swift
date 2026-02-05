import AppKit
import SwiftUI

extension Notification.Name {
    static let paneVisibilityChanged = Notification.Name("paneVisibilityChanged")
}

/// Three-pane split view controller with sidebar, content, and detail regions
class MainSplitViewController: NSSplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = true
        splitView.dividerStyle = .thin

        // Sidebar (collapsible, left)
        let sidebarVC = NSHostingController(
            rootView: WorkspaceListPane()
                .environmentObject(AppState.shared)
                .environmentObject(ThemeManager.shared)
        )
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 300
        sidebarItem.canCollapse = true

        // Content (middle)
        let contentVC = NSHostingController(
            rootView: ClaudeSessionPane()
                .environmentObject(AppState.shared)
                .environmentObject(ThemeManager.shared)
        )
        let contentItem = NSSplitViewItem(contentListWithViewController: contentVC)
        contentItem.minimumThickness = 400

        // Detail (right, collapsible)
        let detailVC = NSHostingController(
            rootView: RightPane()
                .environmentObject(AppState.shared)
                .environmentObject(ThemeManager.shared)
        )
        let detailItem = NSSplitViewItem(viewController: detailVC)
        detailItem.minimumThickness = 280
        detailItem.maximumThickness = 500
        detailItem.canCollapse = true

        addSplitViewItem(sidebarItem)
        addSplitViewItem(contentItem)
        addSplitViewItem(detailItem)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // Set initial divider positions
        splitView.setPosition(220, ofDividerAt: 0)
        splitView.setPosition(splitView.bounds.width - 350, ofDividerAt: 1)
    }

    // MARK: - Pane Toggle Actions

    @objc func toggleLeftSidebar(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            splitViewItems[0].animator().isCollapsed.toggle()
        }
    }

    @objc func toggleRightPane(_ sender: Any?) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            splitViewItems[2].animator().isCollapsed.toggle()
        }
    }

    @objc func toggleBottomPanel(_ sender: Any?) {
        // No-op for now - placeholder for future bottom panel
    }

    var isLeftSidebarCollapsed: Bool {
        splitViewItems[0].isCollapsed
    }

    var isRightPaneCollapsed: Bool {
        splitViewItems[2].isCollapsed
    }

    // MARK: - State Notifications

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        postVisibilityNotification()
    }

    private func postVisibilityNotification() {
        NotificationCenter.default.post(
            name: .paneVisibilityChanged,
            object: nil,
            userInfo: [
                "leftCollapsed": splitViewItems[0].isCollapsed,
                "rightCollapsed": splitViewItems[2].isCollapsed
            ]
        )
    }
}
