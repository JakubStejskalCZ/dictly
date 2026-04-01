import SwiftUI

// MARK: - DictlyAnimation

/// Design token namespace for Dictly's shared animation curves and timing.
///
/// All animations respect `AccessibilityReduceMotion` through the `reduceMotion:`
/// overloads, which return `nil` (no animation) when the system preference is active.
/// Views should read `@Environment(\.accessibilityReduceMotion)` and pass the value
/// to these helpers.
public enum DictlyAnimation {

    // MARK: Tag Placement

    /// Ease-out pulse for tag placement (150ms, scale 0.95 → 1.0).
    public static let tagPlacement: Animation = .easeOut(duration: 0.15)

    /// Spring bounce variant for tag placement (response 150ms, damping 0.6).
    public static let tagPlacementSpring: Animation = .spring(response: 0.15, dampingFraction: 0.6)

    /// Starting scale for the tag placement entrance animation.
    public static let tagPlacementStartScale: CGFloat = 0.96

    // MARK: Recording Indicator

    /// Breathing glow for the recording indicator — 2-second ease-in-out repeating cycle.
    public static let recordingBreath: Animation = .easeInOut(duration: 1.0).repeatForever(autoreverses: true)

    // MARK: Accessibility-Aware Overloads

    /// Returns the tag placement animation, or `nil` when reduce motion is active.
    ///
    /// Use with `withAnimation(DictlyAnimation.tagPlacement(reduceMotion: reduceMotion)) { … }`.
    public static func tagPlacement(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : tagPlacement
    }

    /// Returns the spring tag placement animation, or `nil` when reduce motion is active.
    public static func tagPlacementSpring(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : tagPlacementSpring
    }

    /// Returns the recording breath animation, or `nil` when reduce motion is active.
    public static func recordingBreath(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : recordingBreath
    }
}
