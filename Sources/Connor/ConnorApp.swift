import SwiftUI

@main
struct ConnorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Workspace") {
                    appState.showNewWorkspaceSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

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
        }

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}
