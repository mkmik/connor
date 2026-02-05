import Foundation
import SwiftUI
import Combine

/// Manages theme state and provides reactive color access
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var currentTheme: Theme = .light
    @Published private(set) var allThemes: [Theme] = Theme.builtInThemes

    private init() {}

    // MARK: - Theme Loading

    /// Loads themes from preferences
    func loadThemes(from preferences: Preferences) {
        allThemes = Theme.builtInThemes + preferences.customThemes

        if let selectedId = preferences.selectedThemeId,
           let theme = allThemes.first(where: { $0.id == selectedId }) {
            currentTheme = theme
        } else {
            currentTheme = .light
        }

        notifyThemeChange()
    }

    // MARK: - Theme Selection

    /// Sets the active theme
    func setTheme(_ theme: Theme) {
        guard let found = allThemes.first(where: { $0.id == theme.id }) else { return }
        currentTheme = found
        notifyThemeChange()
    }

    /// Sets the active theme by ID
    func setTheme(id: UUID) {
        guard let theme = allThemes.first(where: { $0.id == id }) else { return }
        setTheme(theme)
    }

    // MARK: - Theme CRUD

    /// Adds a new custom theme
    @discardableResult
    func addTheme(_ theme: Theme) -> Theme {
        var newTheme = theme
        newTheme.isBuiltIn = false
        allThemes.append(newTheme)
        return newTheme
    }

    /// Updates an existing custom theme
    func updateTheme(_ theme: Theme) {
        guard !theme.isBuiltIn else { return }

        if let index = allThemes.firstIndex(where: { $0.id == theme.id }) {
            allThemes[index] = theme

            // If updating the current theme, refresh it
            if currentTheme.id == theme.id {
                currentTheme = theme
                notifyThemeChange()
            }
        }
    }

    /// Deletes a custom theme
    func deleteTheme(_ theme: Theme) {
        guard !theme.isBuiltIn else { return }

        allThemes.removeAll { $0.id == theme.id }

        // If deleted the current theme, fall back to light
        if currentTheme.id == theme.id {
            currentTheme = .light
            notifyThemeChange()
        }
    }

    // MARK: - Helpers

    /// Returns only user-created themes
    var customThemes: [Theme] {
        allThemes.filter { !$0.isBuiltIn }
    }

    /// Notifies observers that the theme has changed
    private func notifyThemeChange() {
        NotificationCenter.default.post(
            name: .themeDidChange,
            object: nil,
            userInfo: ["theme": currentTheme]
        )
    }

    /// Computes a contrasting foreground color for a given background
    static func contrastingColor(for background: NSColor) -> NSColor {
        let rgb = background.usingColorSpace(.sRGB) ?? background
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance > 0.5 ? .black : .white
    }
}
