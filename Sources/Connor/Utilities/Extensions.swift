import Foundation
import SwiftUI

// MARK: - URL Extensions

extension URL {
    /// Returns true if this URL points to a directory
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    /// Returns true if this URL points to a hidden file
    var isHidden: Bool {
        (try? resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true
    }
}

// MARK: - String Extensions

extension String {
    /// Converts a string to a URL-safe slug
    var slugified: String {
        lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

// MARK: - View Extensions

extension View {
    /// Conditionally applies a modifier
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Returns a contrasting text color (black or white) for this background color
    static func contrastingTextColor(for background: NSColor) -> Color {
        let luminance = 0.299 * background.redComponent +
                       0.587 * background.greenComponent +
                       0.114 * background.blueComponent
        return luminance > 0.5 ? .black : .white
    }
}

// MARK: - Date Extensions

extension Date {
    /// Returns a relative time string (e.g., "5 minutes ago")
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
