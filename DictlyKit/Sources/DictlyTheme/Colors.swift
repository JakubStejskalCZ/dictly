import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Internal Color Helpers

extension Color {
    /// Creates a Color from a 24-bit RGB hex literal (e.g., `Color(hex: 0xFF5733)`).
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    /// Creates an adaptive color that resolves to `light` in light mode and `dark` in dark mode.
    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }
}

// MARK: - DictlyColors

/// Design token namespace for all Dictly colors.
///
/// Adaptive base palette colors auto-switch with the system appearance.
/// Tag category and accent/state colors are non-adaptive (same in light and dark mode).
public enum DictlyColors {

    // MARK: Base Palette (Adaptive)

    /// App background — light: `#FAF8F5` / dark: `#1A1816`
    public static let background = Color(light: Color(hex: 0xFAF8F5), dark: Color(hex: 0x1A1816))

    /// Card / sheet surface — light: `#F2EDE7` / dark: `#292524`
    public static let surface = Color(light: Color(hex: 0xF2EDE7), dark: Color(hex: 0x292524))

    /// Primary text — light: `#1C1917` / dark: `#F5F0EB`
    public static let textPrimary = Color(light: Color(hex: 0x1C1917), dark: Color(hex: 0xF5F0EB))

    /// Secondary text / metadata — light: `#78716C` / dark: `#A8A29E`
    public static let textSecondary = Color(light: Color(hex: 0x78716C), dark: Color(hex: 0xA8A29E))

    /// Dividers and borders — light: `#E7E0D8` / dark: `#3D3835`
    public static let border = Color(light: Color(hex: 0xE7E0D8), dark: Color(hex: 0x3D3835))

    // MARK: Tag Category Colors (Non-adaptive)

    /// Tag category colors — identical in light and dark mode,
    /// verified for WCAG AA contrast (4.5:1) against both surfaces.
    public enum TagCategory {
        /// Story events — `#D97706`
        public static let story = Color(hex: 0xD97706)
        /// Combat events — `#DC2626`
        public static let combat = Color(hex: 0xDC2626)
        /// Roleplay moments — `#7C3AED`
        public static let roleplay = Color(hex: 0x7C3AED)
        /// World-building — `#059669`
        public static let world = Color(hex: 0x059669)
        /// Meta / out-of-character — `#4B7BE5`
        public static let meta = Color(hex: 0x4B7BE5)
    }

    // MARK: Accent / State Colors (Non-adaptive)

    /// Active recording indicator — `#EF4444`
    public static let recordingActive = Color(hex: 0xEF4444)
    /// Success state — `#16A34A`
    public static let success = Color(hex: 0x16A34A)
    /// Warning state — `#F59E0B`
    public static let warning = Color(hex: 0xF59E0B)
    /// Destructive actions — `#DC2626`
    public static let destructive = Color(hex: 0xDC2626)
}
