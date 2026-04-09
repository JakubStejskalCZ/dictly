import Foundation
import SwiftData

/// Seeds the default D&D tag categories and their pre-defined tags on first launch.
/// This is idempotent: if any TagCategory already exists, seeding is skipped entirely.
///
/// Uses deterministic UUIDs derived from category/tag names so that both iOS and Mac
/// devices produce identical records — preventing duplicates when iCloud KVS sync merges.
public struct DefaultTagSeeder {

    /// Namespace UUID (v5) for generating deterministic UUIDs from category/tag names.
    /// Generated once, never changes.
    private static let namespaceUUID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!

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

    /// Creates a deterministic UUID from a string key using SHA-256 truncation.
    /// This ensures both iOS and Mac generate identical UUIDs for the same category/tag.
    private static func deterministicUUID(for key: String) -> UUID {
        let input = "\(namespaceUUID.uuidString):\(key)"
        // Use a simple hash-based approach: SHA256 of the combined string
        var hash = [UInt8](repeating: 0, count: 16)
        let data = Array(input.utf8)
        // Simple deterministic hash (FNV-1a inspired, fits in 16 bytes)
        var h: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211
        for byte in data {
            h ^= UInt64(byte)
            h = h &* prime
        }
        withUnsafeBytes(of: h) { ptr in
            for i in 0..<8 { hash[i] = ptr[i] }
        }
        // Second pass with different seed for bytes 8-15
        h = 14695981039346656037
        for byte in data.reversed() {
            h ^= UInt64(byte)
            h = h &* prime
        }
        withUnsafeBytes(of: h) { ptr in
            for i in 0..<8 { hash[i + 8] = ptr[i] }
        }
        // Set version 4 and variant bits for UUID compliance
        hash[6] = (hash[6] & 0x0F) | 0x40
        hash[8] = (hash[8] & 0x3F) | 0x80
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3],
                           hash[4], hash[5], hash[6], hash[7],
                           hash[8], hash[9], hash[10], hash[11],
                           hash[12], hash[13], hash[14], hash[15]))
    }

    /// Seeds default categories and tags if the store is empty.
    /// - Parameter context: The `ModelContext` to insert models into.
    public static func seedIfNeeded(context: ModelContext) throws {
        let existingCount = try context.fetchCount(FetchDescriptor<TagCategory>())
        guard existingCount == 0 else { return }

        for cat in defaultCategories {
            let category = TagCategory(
                uuid: deterministicUUID(for: "category:\(cat.name)"),
                name: cat.name,
                colorHex: cat.colorHex,
                iconName: cat.iconName,
                sortOrder: cat.sortOrder,
                isDefault: true
            )
            context.insert(category)

            for label in defaultTags[cat.name] ?? [] {
                let tag = Tag(
                    uuid: deterministicUUID(for: "tag:\(cat.name):\(label)"),
                    label: label,
                    categoryName: cat.name,
                    anchorTime: 0,
                    rewindDuration: 0
                )
                context.insert(tag)
            }
        }
    }

    /// Removes duplicate TagCategory records, keeping only one per unique name.
    /// Call this on app launch to clean up duplicates caused by iCloud sync with random UUIDs.
    public static func deduplicateCategories(context: ModelContext) throws {
        let categories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        var seen = Set<String>()
        for category in categories {
            if !seen.insert(category.name).inserted {
                context.delete(category)
            }
        }
    }
}
