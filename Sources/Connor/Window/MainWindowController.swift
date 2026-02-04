import AppKit
import SwiftUI

/// Main window controller with 3 title bar regions using NSTrackingSeparatorToolbarItem
class MainWindowController: NSWindowController, NSToolbarDelegate {
    private var splitViewController: MainSplitViewController!

    convenience init() {
        // Create window with fullSizeContentView for title bar integration
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 1200, height: 700)

        self.init(window: window)
        setupSplitViewController()
        setupToolbar()

        // Restore saved window frame AFTER content is set up (to avoid content resizing the window)
        if !window.setFrameUsingName("MainWindow") {
            window.center()
        }
        window.setFrameAutosaveName("MainWindow")
    }

    private func setupSplitViewController() {
        splitViewController = MainSplitViewController()
        window?.contentViewController = splitViewController
    }

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window?.toolbar = toolbar
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .branchDisplay,
            .flexibleSpace,
            .contentTrackingSeparator,
            .openInMenu,
            .createMR
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .sidebarTrackingSeparator:
            // Track first divider (sidebar | content)
            return NSTrackingSeparatorToolbarItem(
                identifier: itemIdentifier,
                splitView: splitViewController.splitView,
                dividerIndex: 0
            )

        case .contentTrackingSeparator:
            // Track second divider (content | detail)
            return NSTrackingSeparatorToolbarItem(
                identifier: itemIdentifier,
                splitView: splitViewController.splitView,
                dividerIndex: 1
            )

        case .branchDisplay:
            return BranchToolbarItem(itemIdentifier: itemIdentifier)

        case .openInMenu:
            return HostedToolbarItem(itemIdentifier, view: OpenInMenuButton())

        case .createMR:
            return HostedToolbarItem(itemIdentifier, view: CreateMRButton())

        default:
            return nil
        }
    }
}
