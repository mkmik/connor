import AppKit
import SwiftUI

extension Notification.Name {
    static let paneVisibilityChanged = Notification.Name("paneVisibilityChanged")
}

/// Main split view controller with nested splits:
/// - Outer (horizontal): [leftSidebar, restVC]
/// - restVC (vertical): [upperVC, bottomTerminal]
/// - upperVC (horizontal): [centerPane, rightSidebar]
class MainSplitViewController: NSSplitViewController {
    // Child split view controllers
    private var restVC: RestSplitViewController!

    /// Tracks the last known width of the left sidebar (persists when collapsed)
    private var lastKnownLeftWidth: CGFloat?

    /// Prevents saving during toggle animation
    private var isAnimatingLeftToggle = false

    /// The split view that divides center and right panes (for toolbar tracking)
    var upperSplitView: NSSplitView {
        restVC.upperSplitView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = true
        splitView.dividerStyle = .thin

        // Left sidebar (collapsible)
        let sidebarVC = NSHostingController(
            rootView: WorkspaceListPane()
                .environmentObject(AppState.shared)
                .environmentObject(ThemeManager.shared)
        )
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 300
        sidebarItem.canCollapse = true

        // Rest container (vertical split: upper + bottom terminal)
        restVC = RestSplitViewController()
        let restItem = NSSplitViewItem(viewController: restVC)
        restItem.minimumThickness = 600

        addSplitViewItem(sidebarItem)
        addSplitViewItem(restItem)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if AppState.shared.preferences.leftPaneWidth == nil {
            splitView.setPosition(220, ofDividerAt: 0)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        restorePaneVisibility()
    }

    // MARK: - Pane Toggle Actions

    @objc func toggleLeftSidebar(_ sender: Any?) {
        let wasCollapsed = splitViewItems[0].isCollapsed
        isAnimatingLeftToggle = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            splitViewItems[0].animator().isCollapsed.toggle()
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            if wasCollapsed, let width = self.lastKnownLeftWidth {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.splitView.setPosition(width, ofDividerAt: 0)
                    self.isAnimatingLeftToggle = false
                    self.savePaneVisibility()
                }
            } else {
                self.isAnimatingLeftToggle = false
                self.savePaneVisibility()
            }
        }
    }

    @objc func toggleRightPane(_ sender: Any?) {
        restVC.toggleRightPane()
        savePaneVisibility()
        postVisibilityNotification()
    }

    @objc func toggleBottomPanel(_ sender: Any?) {
        restVC.toggleBottomPanel()
        savePaneVisibility()
        postVisibilityNotification()
    }

    var isLeftSidebarCollapsed: Bool {
        splitViewItems[0].isCollapsed
    }

    /// The width of the left sidebar (returns last known width even when collapsed)
    var leftSidebarWidth: CGFloat? {
        if !splitViewItems[0].isCollapsed && !isAnimatingLeftToggle {
            lastKnownLeftWidth = splitViewItems[0].viewController.view.frame.width
        }
        return lastKnownLeftWidth
    }

    // MARK: - Pane Visibility Persistence

    func savePaneVisibility() {
        Task { @MainActor in
            AppState.shared.preferences.isLeftPaneVisible = !isLeftSidebarCollapsed
            AppState.shared.preferences.isRightPaneVisible = !restVC.isRightPaneCollapsed
            AppState.shared.preferences.isBottomPanelExpanded = !restVC.isBottomPanelCollapsed
            AppState.shared.preferences.bottomPanelHeight = restVC.bottomPanelHeight
            AppState.shared.preferences.leftPaneWidth = leftSidebarWidth
            AppState.shared.preferences.rightPaneWidth = restVC.rightPaneWidth
            AppState.shared.savePreferences()
        }
    }

    private func restorePaneVisibility() {
        let prefs = AppState.shared.preferences

        if let width = prefs.leftPaneWidth {
            lastKnownLeftWidth = width
        }

        if !prefs.isLeftPaneVisible {
            splitViewItems[0].isCollapsed = true
        }

        if prefs.isLeftPaneVisible, let width = prefs.leftPaneWidth {
            splitView.setPosition(width, ofDividerAt: 0)
        }

        restVC.restoreVisibility(
            rightVisible: prefs.isRightPaneVisible,
            rightWidth: prefs.rightPaneWidth,
            bottomExpanded: prefs.isBottomPanelExpanded,
            bottomHeight: prefs.bottomPanelHeight
        )
    }

    // MARK: - State Notifications

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        if !isAnimatingLeftToggle {
            savePaneVisibility()
        }
        postVisibilityNotification()
    }

    private func postVisibilityNotification() {
        NotificationCenter.default.post(
            name: .paneVisibilityChanged,
            object: nil,
            userInfo: [
                "leftCollapsed": isLeftSidebarCollapsed,
                "rightCollapsed": restVC.isRightPaneCollapsed,
                "bottomPanelExpanded": !restVC.isBottomPanelCollapsed
            ]
        )
    }
}

// MARK: - Rest Split View Controller (vertical: upper + bottom)

/// Vertical split: upper content area + bottom terminal panel
class RestSplitViewController: NSSplitViewController {
    private var upperVC: UpperSplitViewController!
    private var bottomItem: NSSplitViewItem!

    /// Tracks the last known height of the bottom panel (persists when collapsed)
    private var lastKnownBottomHeight: CGFloat?

    /// Prevents saving during toggle animation (to avoid overwriting the target height)
    private var isAnimatingToggle = false

    /// The split view that divides center and right panes (for toolbar tracking)
    var upperSplitView: NSSplitView {
        upperVC.splitView
    }

    var isRightPaneCollapsed: Bool {
        upperVC.isRightPaneCollapsed
    }

    var isBottomPanelCollapsed: Bool {
        bottomItem.isCollapsed
    }

    var rightPaneWidth: CGFloat? {
        upperVC.rightPaneWidth
    }

    /// The height of the bottom panel (returns last known height even when collapsed)
    var bottomPanelHeight: CGFloat? {
        // Don't update during toggle animation to preserve the target height
        if !bottomItem.isCollapsed && !isAnimatingToggle {
            // Update and return current height
            lastKnownBottomHeight = bottomItem.viewController.view.frame.height
        }
        return lastKnownBottomHeight
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = false  // Vertical split (top/bottom)
        splitView.dividerStyle = .thin

        // Upper content (horizontal split: center + right)
        upperVC = UpperSplitViewController()
        let upperItem = NSSplitViewItem(viewController: upperVC)
        upperItem.minimumThickness = 200

        // Bottom terminal panel (collapsible)
        let bottomVC = NSHostingController(
            rootView: SharedTerminalSection()
                .environmentObject(AppState.shared)
                .environmentObject(ThemeManager.shared)
        )
        bottomItem = NSSplitViewItem(viewController: bottomVC)
        bottomItem.minimumThickness = 150
        bottomItem.canCollapse = true
        // Start collapsed by default (bottom panel hidden)
        bottomItem.isCollapsed = true

        addSplitViewItem(upperItem)
        addSplitViewItem(bottomItem)
    }

    func toggleRightPane() {
        upperVC.toggleRightPane()
    }

    /// Toggles the bottom panel visibility with animation.
    ///
    /// Uses `isAnimatingToggle` flag to prevent `splitViewDidResizeSubviews` from overwriting
    /// the saved height during the expand animation. Without this protection, the resize
    /// notifications that fire during animation would read the intermediate (minimum) height
    /// and overwrite `lastKnownBottomHeight` before we can restore it.
    func toggleBottomPanel() {
        let wasCollapsed = bottomItem.isCollapsed

        // Prevent splitViewDidResizeSubviews from overwriting the saved height during animation
        isAnimatingToggle = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            bottomItem.animator().isCollapsed.toggle()
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            // If expanding and we have a saved height, restore it after layout settles
            if wasCollapsed, let height = self.lastKnownBottomHeight {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let totalHeight = self.splitView.bounds.height
                    let dividerPosition = totalHeight - height
                    self.splitView.setPosition(dividerPosition, ofDividerAt: 0)
                    self.isAnimatingToggle = false
                    // Save state after restoration
                    if let parent = self.parent as? MainSplitViewController {
                        parent.savePaneVisibility()
                    }
                }
            } else {
                self.isAnimatingToggle = false
            }
        }
    }

    func restoreVisibility(rightVisible: Bool, rightWidth: CGFloat?, bottomExpanded: Bool, bottomHeight: CGFloat?) {
        upperVC.restoreRightPaneVisibility(visible: rightVisible, width: rightWidth)

        // Store the saved height (even if panel is collapsed, so it's remembered)
        if let height = bottomHeight {
            lastKnownBottomHeight = height
        }

        bottomItem.isCollapsed = !bottomExpanded

        // Restore bottom panel height if available and expanded
        if bottomExpanded, let height = bottomHeight {
            // Set the divider position: total height - bottom panel height
            let totalHeight = splitView.bounds.height
            let dividerPosition = totalHeight - height
            splitView.setPosition(dividerPosition, ofDividerAt: 0)
        }
    }

    // Save state when bottom panel divider is moved
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        // Don't save during toggle animation (to preserve the target height)
        guard !isAnimatingToggle else { return }
        // Notify parent to save the updated height
        if let parent = parent as? MainSplitViewController {
            parent.savePaneVisibility()
        }
    }
}

// MARK: - Upper Split View Controller (horizontal: center + right)

/// Horizontal split: center pane + right sidebar
class UpperSplitViewController: NSSplitViewController {
    private var rightItem: NSSplitViewItem!

    /// Tracks the last known width of the right pane (persists when collapsed)
    private var lastKnownRightWidth: CGFloat?

    /// Prevents saving during toggle animation
    private var isAnimatingRightToggle = false

    var isRightPaneCollapsed: Bool {
        rightItem.isCollapsed
    }

    var rightPaneWidth: CGFloat? {
        if !rightItem.isCollapsed && !isAnimatingRightToggle {
            lastKnownRightWidth = rightItem.viewController.view.frame.width
        }
        return lastKnownRightWidth
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = true  // Horizontal split (left/right)
        splitView.dividerStyle = .thin

        // Center pane (Claude terminal)
        let centerVC = NSHostingController(
            rootView: ClaudeSessionPane()
                .environmentObject(AppState.shared)
                .environmentObject(ThemeManager.shared)
        )
        let centerItem = NSSplitViewItem(contentListWithViewController: centerVC)
        centerItem.minimumThickness = 400

        // Right sidebar (files/changes/checks + terminal when bottom collapsed)
        let rightVC = NSHostingController(
            rootView: RightPaneContent()
                .environmentObject(AppState.shared)
                .environmentObject(ThemeManager.shared)
        )
        rightItem = NSSplitViewItem(viewController: rightVC)
        rightItem.minimumThickness = 280
        rightItem.maximumThickness = 500
        rightItem.canCollapse = true

        addSplitViewItem(centerItem)
        addSplitViewItem(rightItem)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if AppState.shared.preferences.rightPaneWidth == nil {
            splitView.setPosition(splitView.bounds.width - 350, ofDividerAt: 0)
        }
    }

    func toggleRightPane() {
        let wasCollapsed = rightItem.isCollapsed
        isAnimatingRightToggle = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            rightItem.animator().isCollapsed.toggle()
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            if wasCollapsed, let width = self.lastKnownRightWidth {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let dividerPosition = self.splitView.bounds.width - width
                    self.splitView.setPosition(dividerPosition, ofDividerAt: 0)
                    self.isAnimatingRightToggle = false
                    self.notifyParentToSave()
                }
            } else {
                self.isAnimatingRightToggle = false
            }
        }
    }

    func restoreRightPaneVisibility(visible: Bool, width: CGFloat?) {
        if let width = width {
            lastKnownRightWidth = width
        }
        rightItem.isCollapsed = !visible
        if visible, let width = width {
            let dividerPosition = splitView.bounds.width - width
            splitView.setPosition(dividerPosition, ofDividerAt: 0)
        }
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        guard !isAnimatingRightToggle else { return }
        notifyParentToSave()
    }

    private func notifyParentToSave() {
        if let restVC = parent as? RestSplitViewController,
           let mainVC = restVC.parent as? MainSplitViewController {
            mainVC.savePaneVisibility()
        }
    }
}

// MARK: - Right Pane Content

/// Right pane content that shows terminal only when bottom panel is collapsed
struct RightPaneContent: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var isBottomPanelExpanded: Bool {
        appState.preferences.isBottomPanelExpanded
    }

    var body: some View {
        if isBottomPanelExpanded {
            // Bottom panel is expanded, so terminal is there - just show files/changes/checks
            RightPaneTopSection()
                .id("rightPane-topOnly")
        } else {
            // Bottom panel is collapsed - show full right pane with terminal
            RightPane()
                .id("rightPane-full")
        }
    }
}
