import SwiftUI
import DictlyTheme

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
