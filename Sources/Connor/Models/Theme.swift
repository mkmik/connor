import Foundation
import SwiftUI
import AppKit

/// A single color that can be serialized as a hex string
struct ThemeColor: Codable, Equatable, Hashable {
    var hex: String  // Format: "#RRGGBB"

    init(hex: String) {
        // Normalize to include # prefix
        if hex.hasPrefix("#") {
            self.hex = hex.uppercased()
        } else {
            self.hex = "#" + hex.uppercased()
        }
    }

    init(nsColor: NSColor) {
        let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        self.hex = String(format: "#%02X%02X%02X", r, g, b)
    }

    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    /// Validates if a string is a valid hex color
    static func isValidHex(_ string: String) -> Bool {
        let pattern = "^#?[0-9A-Fa-f]{6}$"
        return string.range(of: pattern, options: .regularExpression) != nil
    }
}

/// Represents a complete theme with all background colors
struct Theme: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var isBuiltIn: Bool

    // Terminal backgrounds
    var centralTerminalBackground: ThemeColor
    var rightTerminalBackground: ThemeColor

    // Left pane
    var leftPaneBackground: ThemeColor
    var leftWorkspaceListBackground: ThemeColor

    // Right pane content areas
    var rightFileManagerBackground: ThemeColor
    var rightChangesBackground: ThemeColor
    var rightChecksBackground: ThemeColor

    // Toolbars
    var centralToolbarBackground: ThemeColor
    var rightToolbarBackground: ThemeColor

    init(
        id: UUID = UUID(),
        name: String,
        isBuiltIn: Bool = false,
        centralTerminalBackground: ThemeColor,
        rightTerminalBackground: ThemeColor,
        leftPaneBackground: ThemeColor,
        leftWorkspaceListBackground: ThemeColor,
        rightFileManagerBackground: ThemeColor,
        rightChangesBackground: ThemeColor,
        rightChecksBackground: ThemeColor,
        centralToolbarBackground: ThemeColor,
        rightToolbarBackground: ThemeColor
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.centralTerminalBackground = centralTerminalBackground
        self.rightTerminalBackground = rightTerminalBackground
        self.leftPaneBackground = leftPaneBackground
        self.leftWorkspaceListBackground = leftWorkspaceListBackground
        self.rightFileManagerBackground = rightFileManagerBackground
        self.rightChangesBackground = rightChangesBackground
        self.rightChecksBackground = rightChecksBackground
        self.centralToolbarBackground = centralToolbarBackground
        self.rightToolbarBackground = rightToolbarBackground
    }

    /// Creates a copy of this theme with a new ID and name
    func duplicate(newName: String) -> Theme {
        Theme(
            id: UUID(),
            name: newName,
            isBuiltIn: false,
            centralTerminalBackground: centralTerminalBackground,
            rightTerminalBackground: rightTerminalBackground,
            leftPaneBackground: leftPaneBackground,
            leftWorkspaceListBackground: leftWorkspaceListBackground,
            rightFileManagerBackground: rightFileManagerBackground,
            rightChangesBackground: rightChangesBackground,
            rightChecksBackground: rightChecksBackground,
            centralToolbarBackground: centralToolbarBackground,
            rightToolbarBackground: rightToolbarBackground
        )
    }

    // MARK: - Built-in Themes

    /// Light theme with white/light gray backgrounds
    static let light = Theme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Light",
        isBuiltIn: true,
        centralTerminalBackground: ThemeColor(hex: "#FFFFFF"),
        rightTerminalBackground: ThemeColor(hex: "#FFFFFF"),
        leftPaneBackground: ThemeColor(hex: "#F5F5F5"),
        leftWorkspaceListBackground: ThemeColor(hex: "#F5F5F5"),
        rightFileManagerBackground: ThemeColor(hex: "#FFFFFF"),
        rightChangesBackground: ThemeColor(hex: "#FFFFFF"),
        rightChecksBackground: ThemeColor(hex: "#FFFFFF"),
        centralToolbarBackground: ThemeColor(hex: "#ECECEC"),
        rightToolbarBackground: ThemeColor(hex: "#FFFFFF")
    )

    /// Dark theme with dark gray/black backgrounds
    static let dark = Theme(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Dark",
        isBuiltIn: true,
        centralTerminalBackground: ThemeColor(hex: "#1E1E1E"),
        rightTerminalBackground: ThemeColor(hex: "#1E1E1E"),
        leftPaneBackground: ThemeColor(hex: "#252526"),
        leftWorkspaceListBackground: ThemeColor(hex: "#252526"),
        rightFileManagerBackground: ThemeColor(hex: "#1E1E1E"),
        rightChangesBackground: ThemeColor(hex: "#1E1E1E"),
        rightChecksBackground: ThemeColor(hex: "#1E1E1E"),
        centralToolbarBackground: ThemeColor(hex: "#3C3C3C"),
        rightToolbarBackground: ThemeColor(hex: "#252526")
    )

    /// All built-in themes
    static var builtInThemes: [Theme] {
        [.light, .dark]
    }
}

// MARK: - Notification

extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}
