import Foundation
import SwiftData

/// Seeds the default D&D tag categories and their pre-defined tags on first launch.
/// This is idempotent: if any TagCategory already exists, seeding is skipped entirely.
public struct DefaultTagSeeder {

    public static let defaultCategories: [(name: String, colorHex: String, iconName: String, sortOrder: Int)] = [
        ("Story",    "#D97706", "book.pages",    0),
        ("Combat",   "#DC2626", "shield",         1),
        ("Roleplay", "#7C3AED", "theatermasks",   2),
        ("World",    "#059669", "globe",          3),
        ("Meta",     "#4B7BE5", "info.circle",    4)
    ]

    public static let defaultTags: [String: [String]] = [
        "Story":    ["Plot Hook", "Lore Drop", "Quest Update", "Foreshadowing", "Revelation"],
        "Combat":   ["Initiative", "Epic Roll", "Critical Hit", "Encounter Start", "Encounter End"],
        "Roleplay": ["Character Moment", "NPC Introduction", "Memorable Quote", "In-Character Speech", "Emotional Beat"],
        "World":    ["Location", "Item", "Lore", "Map Note", "Environment Description"],
        "Meta":     ["Ruling", "House Rule", "Schedule", "Break", "Player Note"]
    ]

    /// Seeds default categories and tags if the store is empty.
    /// - Parameter context: The `ModelContext` to insert models into.
    public static func seedIfNeeded(context: ModelContext) throws {
        let existingCount = try context.fetchCount(FetchDescriptor<TagCategory>())
        guard existingCount == 0 else { return }

        for cat in defaultCategories {
            let category = TagCategory(
                name: cat.name,
                colorHex: cat.colorHex,
                iconName: cat.iconName,
                sortOrder: cat.sortOrder,
                isDefault: true
            )
            context.insert(category)

            for label in defaultTags[cat.name] ?? [] {
                let tag = Tag(
                    label: label,
                    categoryName: cat.name,
                    anchorTime: 0,
                    rewindDuration: 0
                )
                context.insert(tag)
            }
        }
    }
}
