import SwiftUI

// MARK: - View Modifier for Themed Backgrounds

/// View modifier that applies a themed background color
struct ThemedBackgroundModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    let colorKeyPath: KeyPath<Theme, ThemeColor>

    func body(content: Content) -> some View {
        content
            .background(themeManager.currentTheme[keyPath: colorKeyPath].color)
    }
}

extension View {
    /// Applies a background color from the current theme
    func themedBackground(_ keyPath: KeyPath<Theme, ThemeColor>) -> some View {
        modifier(ThemedBackgroundModifier(colorKeyPath: keyPath))
    }
}

// MARK: - Theme Color Accessor

/// Provides convenient access to theme colors with automatic updates
struct ThemeColors {
    let theme: Theme

    var centralTerminalBackground: Color { theme.centralTerminalBackground.color }
    var rightTerminalBackground: Color { theme.rightTerminalBackground.color }
    var leftPaneBackground: Color { theme.leftPaneBackground.color }
    var leftWorkspaceListBackground: Color { theme.leftWorkspaceListBackground.color }
    var rightFileManagerBackground: Color { theme.rightFileManagerBackground.color }
    var rightChangesBackground: Color { theme.rightChangesBackground.color }
    var rightChecksBackground: Color { theme.rightChecksBackground.color }
    var centralToolbarBackground: Color { theme.centralToolbarBackground.color }
    var rightToolbarBackground: Color { theme.rightToolbarBackground.color }
}

extension ThemeManager {
    var colors: ThemeColors {
        ThemeColors(theme: currentTheme)
    }
}
