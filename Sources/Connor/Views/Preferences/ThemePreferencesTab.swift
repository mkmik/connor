import SwiftUI

struct ThemePreferencesTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedThemeId: UUID?
    @State private var editingTheme: Theme?
    @State private var showingNewThemeSheet = false

    var body: some View {
        HSplitView {
            // Left: Theme list
            themeListSection
                .frame(minWidth: 150, maxWidth: 200)

            // Right: Theme editor
            if let theme = editingTheme {
                ThemeEditorView(
                    theme: Binding(
                        get: { theme },
                        set: { editingTheme = $0 }
                    ),
                    onSave: saveTheme
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Spacer()
                    Text("Select a theme to edit")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .onAppear {
            selectedThemeId = themeManager.currentTheme.id
            editingTheme = themeManager.currentTheme
        }
    }

    private var themeListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THEMES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            List(themeManager.allThemes, selection: $selectedThemeId) { theme in
                HStack {
                    // Active indicator
                    Circle()
                        .fill(themeManager.currentTheme.id == theme.id ? Color.accentColor : Color.clear)
                        .frame(width: 8, height: 8)

                    Text(theme.name)
                        .lineLimit(1)

                    Spacer()

                    if theme.isBuiltIn {
                        Text("Built-in")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .tag(theme.id)
            }
            .listStyle(.bordered)
            .onChange(of: selectedThemeId) { _, newId in
                if let id = newId,
                   let theme = themeManager.allThemes.first(where: { $0.id == id }) {
                    editingTheme = theme
                }
            }

            // Buttons
            HStack(spacing: 8) {
                Button(action: { showingNewThemeSheet = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)

                Button(action: deleteSelectedTheme) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(editingTheme?.isBuiltIn ?? true)

                Spacer()
            }

            Divider()

            // Apply button
            Button("Apply Theme") {
                applySelectedTheme()
            }
            .buttonStyle(.borderedProminent)
            .disabled(editingTheme == nil)
        }
        .sheet(isPresented: $showingNewThemeSheet) {
            NewThemeSheet(
                existingThemes: themeManager.allThemes,
                onCreate: createNewTheme
            )
        }
    }

    private func applySelectedTheme() {
        guard let theme = editingTheme else { return }
        themeManager.setTheme(theme)
        appState.preferences.selectedThemeId = theme.id
        appState.savePreferences()
    }

    private func saveTheme(_ theme: Theme) {
        if theme.isBuiltIn { return }
        themeManager.updateTheme(theme)
        appState.preferences.customThemes = themeManager.customThemes
        appState.savePreferences()

        // If this is the current theme, apply changes immediately
        if themeManager.currentTheme.id == theme.id {
            themeManager.setTheme(theme)
        }
    }

    private func createNewTheme(_ theme: Theme) {
        let added = themeManager.addTheme(theme)
        appState.preferences.customThemes = themeManager.customThemes
        appState.savePreferences()
        selectedThemeId = added.id
        editingTheme = added
    }

    private func deleteSelectedTheme() {
        guard let theme = editingTheme, !theme.isBuiltIn else { return }

        themeManager.deleteTheme(theme)
        appState.preferences.customThemes = themeManager.customThemes

        // If deleted the active theme, update selection
        if appState.preferences.selectedThemeId == theme.id {
            appState.preferences.selectedThemeId = Theme.light.id
        }

        appState.savePreferences()

        // Select light theme in the list
        selectedThemeId = Theme.light.id
        editingTheme = Theme.light
    }
}
