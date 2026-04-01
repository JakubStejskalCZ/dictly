import SwiftUI

// MARK: - DictlyTypography

/// Design token namespace for Dictly's type scale.
///
/// Sizes are defined per the UX specification with platform-conditional values.
/// iOS sizes are larger to accommodate touch interactions; Mac sizes are tighter
/// for desktop density. Use `Font.system(size:weight:)` directly — not semantic
/// text styles — so the UX-specified sizes are respected as baselines.
public enum DictlyTypography {

    // MARK: Display

    /// Display text — iOS: 34pt Bold / Mac: 28pt Bold
    #if os(iOS)
    public static let display: Font = .system(size: 34, weight: .bold)
    #else
    public static let display: Font = .system(size: 28, weight: .bold)
    #endif

    // MARK: Headings

    /// H1 heading — iOS: 28pt Bold / Mac: 24pt Bold
    #if os(iOS)
    public static let h1: Font = .system(size: 28, weight: .bold)
    #else
    public static let h1: Font = .system(size: 24, weight: .bold)
    #endif

    /// H2 heading — iOS: 22pt Semibold / Mac: 20pt Semibold
    #if os(iOS)
    public static let h2: Font = .system(size: 22, weight: .semibold)
    #else
    public static let h2: Font = .system(size: 20, weight: .semibold)
    #endif

    /// H3 heading — iOS: 17pt Semibold / Mac: 16pt Semibold
    #if os(iOS)
    public static let h3: Font = .system(size: 17, weight: .semibold)
    #else
    public static let h3: Font = .system(size: 16, weight: .semibold)
    #endif

    // MARK: Body

    /// Body text — iOS: 17pt Regular / Mac: 14pt Regular
    #if os(iOS)
    public static let body: Font = .system(size: 17, weight: .regular)
    #else
    public static let body: Font = .system(size: 14, weight: .regular)
    #endif

    /// Caption / metadata — iOS: 13pt Regular / Mac: 12pt Regular
    #if os(iOS)
    public static let caption: Font = .system(size: 13, weight: .regular)
    #else
    public static let caption: Font = .system(size: 12, weight: .regular)
    #endif

    /// Tag label — iOS: 14pt Medium / Mac: 13pt Medium
    #if os(iOS)
    public static let tagLabel: Font = .system(size: 14, weight: .medium)
    #else
    public static let tagLabel: Font = .system(size: 13, weight: .medium)
    #endif

    // MARK: Monospaced Digits

    /// Monospaced digits for timers, timestamps, and tag counts.
    /// Uses body size with SF Mono digit rendering via `.monospacedDigit()`.
    #if os(iOS)
    public static let monospacedDigits: Font = Font.system(size: 17, weight: .regular).monospacedDigit()
    #else
    public static let monospacedDigits: Font = Font.system(size: 14, weight: .regular).monospacedDigit()
    #endif
}
