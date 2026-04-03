import SwiftUI
import DictlyTheme

extension Color {
    /// Creates a Color from a CSS hex string (e.g., `"#D97706"` or `"D97706"`).
    init(hexString: String) {
        let raw = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        let value = UInt32(raw, radix: 16) ?? 0
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >>  8) & 0xFF) / 255.0,
            blue:  Double( value        & 0xFF) / 255.0
        )
    }
}

/// Shared category color lookup used by tag sidebar rows and detail panels.
func categoryColor(for name: String) -> Color {
    switch name.lowercased() {
    case "story":    return DictlyColors.TagCategory.story
    case "combat":   return DictlyColors.TagCategory.combat
    case "roleplay": return DictlyColors.TagCategory.roleplay
    case "world":    return DictlyColors.TagCategory.world
    case "meta":     return DictlyColors.TagCategory.meta
    default:         return DictlyColors.textSecondary
    }
}
