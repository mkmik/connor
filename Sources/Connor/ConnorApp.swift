import SwiftUI

@main
struct ConnorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1400, height: 900)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New Workspace") {
                    appState.showNewWorkspaceSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            // View menu - Navigation
            CommandGroup(after: .sidebar) {
                Button("Go Back") {
                    appState.navigateBack()
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!appState.canNavigateBack)

                Button("Go Forward") {
                    appState.navigateForward()
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!appState.canNavigateForward)
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("Connor Help") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/mkmik/connor")!)
                }
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}

/// AppDelegate to ensure proper menu bar behavior
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app has a proper activation policy for menu bar
        NSApp.setActivationPolicy(.regular)

        // Set the app icon from bundle resources
        if let iconImage = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = iconImage
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
