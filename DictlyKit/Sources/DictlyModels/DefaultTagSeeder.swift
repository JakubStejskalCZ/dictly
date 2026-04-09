import Foundation
import OSLog
import SwiftData

/// Manages tag pack installation and removal.
/// Uses deterministic UUIDs so both iOS and Mac generate identical records,
/// preventing duplicates when iCloud KVS sync merges.
@MainActor
public struct DefaultTagSeeder {

    /// Namespace UUID for generating deterministic UUIDs from category/tag names.
    private static let namespaceUUID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!

    /// Creates a deterministic UUID from a string key using FNV-1a hash.
    private static func deterministicUUID(for key: String) -> UUID {
        let input = "\(namespaceUUID.uuidString):\(key)"
        var hash = [UInt8](repeating: 0, count: 16)
        let data = Array(input.utf8)
        var h: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211
        for byte in data {
            h ^= UInt64(byte)
            h = h &* prime
        }
        withUnsafeBytes(of: h) { ptr in
            for i in 0..<8 { hash[i] = ptr[i] }
        }
        h = 14695981039346656037
        for byte in data.reversed() {
            h ^= UInt64(byte)
            h = h &* prime
        }
        withUnsafeBytes(of: h) { ptr in
            for i in 0..<8 { hash[i + 8] = ptr[i] }
        }
        hash[6] = (hash[6] & 0x0F) | 0x40
        hash[8] = (hash[8] & 0x3F) | 0x80
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3],
                           hash[4], hash[5], hash[6], hash[7],
                           hash[8], hash[9], hash[10], hash[11],
                           hash[12], hash[13], hash[14], hash[15]))
    }

    /// Returns the set of deterministic category UUIDs for a pack.
    private static func categoryUUIDs(for pack: TagPack) -> Set<UUID> {
        Set(pack.categories.map { deterministicUUID(for: "category:\(pack.id):\($0.name)") })
    }

    /// Returns the set of deterministic tag UUIDs for a pack.
    private static func tagUUIDs(for pack: TagPack) -> Set<UUID> {
        var uuids = Set<UUID>()
        for cat in pack.categories {
            for label in pack.tags[cat.name] ?? [] {
                uuids.insert(deterministicUUID(for: "tag:\(pack.id):\(cat.name):\(label)"))
            }
        }
        return uuids
    }

    /// Installs a tag pack — creates its categories and template tags.
    /// Skips categories/tags that already exist (by deterministic UUID).
    public static func installPack(_ pack: TagPack, startingSortOrder: Int, context: ModelContext) throws {
        let existingCategoryUUIDs = Set(try context.fetch(FetchDescriptor<TagCategory>()).map(\.uuid))
        let existingTagUUIDs = Set(try context.fetch(FetchDescriptor<Tag>()).map(\.uuid))

        for (index, cat) in pack.categories.enumerated() {
            let catUUID = deterministicUUID(for: "category:\(pack.id):\(cat.name)")
            if !existingCategoryUUIDs.contains(catUUID) {
                let category = TagCategory(
                    uuid: catUUID,
                    name: cat.name,
                    colorHex: cat.colorHex,
                    iconName: cat.iconName,
                    sortOrder: startingSortOrder + index,
                    isDefault: true
                )
                context.insert(category)
            }

            for label in pack.tags[cat.name] ?? [] {
                let tagUUID = deterministicUUID(for: "tag:\(pack.id):\(cat.name):\(label)")
                if !existingTagUUIDs.contains(tagUUID) {
                    let tag = Tag(
                        uuid: tagUUID,
                        label: label,
                        categoryName: cat.name,
                        anchorTime: 0,
                        rewindDuration: 0
                    )
                    context.insert(tag)
                }
            }
        }
        try context.save()
    }

    /// Uninstalls a tag pack — removes its categories and their template tags.
    /// Session tags whose category is removed are reassigned to "Uncategorized".
    public static func uninstallPack(_ pack: TagPack, context: ModelContext) throws {
        let packCatUUIDs = categoryUUIDs(for: pack)
        let packTagUUIDs = tagUUIDs(for: pack)

        // Delete template tags belonging to this pack (by UUID)
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        for tag in allTags where tag.session == nil && packTagUUIDs.contains(tag.uuid) {
            context.delete(tag)
        }

        // Find category names being removed so we can reassign session tags
        let allCategories = try context.fetch(FetchDescriptor<TagCategory>())
        let categoriesToDelete = allCategories.filter { packCatUUIDs.contains($0.uuid) }
        let removedNames = Set(categoriesToDelete.map(\.name))

        // Only reassign if no other category with that name will remain
        let survivingNames = Set(allCategories.filter { !packCatUUIDs.contains($0.uuid) }.map(\.name))
        let orphanedNames = removedNames.subtracting(survivingNames)

        let sessionTags = allTags.filter { $0.session != nil && orphanedNames.contains($0.categoryName) }
        if !sessionTags.isEmpty {
            try ensureUncategorizedExists(context: context)
            for tag in sessionTags {
                tag.categoryName = "Uncategorized"
            }
        }

        for category in categoriesToDelete {
            context.delete(category)
        }

        try context.save()
    }

    /// Returns IDs of packs whose categories are all present in the database (by UUID).
    public static func installedPackIDs(context: ModelContext) throws -> Set<String> {
        let existingUUIDs = Set(try context.fetch(FetchDescriptor<TagCategory>()).map(\.uuid))
        var installed = Set<String>()
        for pack in TagPackRegistry.all {
            let packCatUUIDs = categoryUUIDs(for: pack)
            if packCatUUIDs.isSubset(of: existingUUIDs) {
                installed.insert(pack.id)
            }
        }
        return installed
    }

    /// Returns the next available sort order value.
    public static func nextSortOrder(context: ModelContext) throws -> Int {
        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        return (categories.map(\.sortOrder).max() ?? -1) + 1
    }

    /// Removes all default categories and their template tags (fresh-start wipe).
    /// Session tags whose category is removed are reassigned to "Uncategorized".
    public static func removeAllDefaultData(context: ModelContext) throws {
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        for tag in allTags where tag.session == nil {
            context.delete(tag)
        }

        let allCategories = try context.fetch(FetchDescriptor<TagCategory>())
        let defaultCategories = allCategories.filter(\.isDefault)
        let removedNames = Set(defaultCategories.map(\.name))
        let survivingNames = Set(allCategories.filter { !$0.isDefault }.map(\.name))
        let orphanedNames = removedNames.subtracting(survivingNames)

        let sessionTags = allTags.filter { $0.session != nil && orphanedNames.contains($0.categoryName) }
        if !sessionTags.isEmpty {
            try ensureUncategorizedExists(context: context)
            for tag in sessionTags {
                tag.categoryName = "Uncategorized"
            }
        }

        for category in defaultCategories {
            context.delete(category)
        }
        try context.save()
    }

    /// Removes duplicate TagCategory records, keeping only one per unique name.
    public static func deduplicateCategories(context: ModelContext) throws {
        let categories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        var seen = Set<String>()
        for category in categories {
            if !seen.insert(category.name).inserted {
                context.delete(category)
            }
        }
    }

    private static func ensureUncategorizedExists(context: ModelContext) throws {
        let allCategories = try context.fetch(FetchDescriptor<TagCategory>())
        guard !allCategories.contains(where: { $0.name == "Uncategorized" }) else { return }
        let maxSort = allCategories.map(\.sortOrder).max() ?? -1
        let uncategorized = TagCategory(
            uuid: deterministicUUID(for: "category:system:Uncategorized"),
            name: "Uncategorized",
            colorHex: "#6B7280",
            iconName: "tag",
            sortOrder: maxSort + 1,
            isDefault: false
        )
        context.insert(uncategorized)
    }
}

private let logger = Logger(subsystem: "com.dictly", category: "TagSeeder")
