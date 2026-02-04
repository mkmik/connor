import SwiftUI

@main
struct ConnorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
                .environmentObject(AppState.shared)
        }
    }
}

/// AppDelegate handles window creation and menu commands
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app has a proper activation policy for menu bar
        NSApp.setActivationPolicy(.regular)

        // Set the app icon from bundle resources
        if let iconImage = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = iconImage
        }

        // Create and show main window
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Set up menu commands
        setupMenuCommands()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure window frame is saved before termination
        mainWindowController?.window?.saveFrame(usingName: "MainWindow")
    }

    // MARK: - Menu Commands

    private func setupMenuCommands() {
        // Wire up menu items to actions
        // File > New Workspace (Cmd+N)
        if let fileMenu = NSApp.mainMenu?.item(withTitle: "File")?.submenu {
            let newWorkspaceItem = NSMenuItem(
                title: "New Workspace",
                action: #selector(newWorkspace(_:)),
                keyEquivalent: "n"
            )
            newWorkspaceItem.target = self
            // Replace the default "New" item or add at top
            if let existingNew = fileMenu.item(withTitle: "New") {
                let index = fileMenu.index(of: existingNew)
                fileMenu.removeItem(existingNew)
                fileMenu.insertItem(newWorkspaceItem, at: index)
            } else {
                fileMenu.insertItem(newWorkspaceItem, at: 0)
            }
        }

        // View > Go Back (Cmd+[) and Go Forward (Cmd+])
        if let viewMenu = NSApp.mainMenu?.item(withTitle: "View")?.submenu {
            viewMenu.addItem(NSMenuItem.separator())

            let goBackItem = NSMenuItem(
                title: "Go Back",
                action: #selector(navigateBack(_:)),
                keyEquivalent: "["
            )
            goBackItem.target = self
            viewMenu.addItem(goBackItem)

            let goForwardItem = NSMenuItem(
                title: "Go Forward",
                action: #selector(navigateForward(_:)),
                keyEquivalent: "]"
            )
            goForwardItem.target = self
            viewMenu.addItem(goForwardItem)
        }
    }

    @objc func newWorkspace(_ sender: Any?) {
        Task { @MainActor in
            AppState.shared.showNewWorkspaceSheet = true
        }
    }

    @objc func navigateBack(_ sender: Any?) {
        Task { @MainActor in
            AppState.shared.navigateBack()
        }
    }

    @objc func navigateForward(_ sender: Any?) {
        Task { @MainActor in
            AppState.shared.navigateForward()
        }
    }

    // MARK: - Menu Validation

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(navigateBack(_:)):
            return AppState.shared.canNavigateBack
        case #selector(navigateForward(_:)):
            return AppState.shared.canNavigateForward
        default:
            return true
        }
    }
}
