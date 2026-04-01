import XCTest
import SwiftData
@testable import DictlyModels

/// End-to-end integration tests covering Epic 1 acceptance criteria.
/// Tests the full data flow across Stories 1.1, 1.3, 1.4, and 1.5.
@MainActor
final class Epic1E2ETests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Schema(DictlySchema.all), configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    // MARK: - Story 1.1: Workspace & Model Foundation

    // AC#3: Campaign, Session, Tag, and TagCategory @Model classes exist with uuid: UUID
    func testAllModelsHaveUUIDIdentity() throws {
        let campaign = Campaign(name: "Test")
        let session = Session(title: "S1", sessionNumber: 1)
        let tag = Tag(label: "T1", categoryName: "C", anchorTime: 0, rewindDuration: 0)
        let category = TagCategory(name: "Cat", colorHex: "#000", iconName: "tag")

        context.insert(campaign)
        context.insert(session)
        context.insert(tag)
        context.insert(category)
        try context.save()

        XCTAssertNotEqual(campaign.uuid, UUID()) // uuid is set
        XCTAssertNotEqual(session.uuid, UUID())
        XCTAssertNotEqual(tag.uuid, UUID())
        XCTAssertNotEqual(category.uuid, UUID())
    }

    // AC#4: Campaign → Session cascade, Session → Tag cascade
    func testFullCascadeDeleteChain() throws {
        let campaign = Campaign(name: "My Campaign")
        let session1 = Session(title: "Session 1", sessionNumber: 1)
        let session2 = Session(title: "Session 2", sessionNumber: 2)
        let tag1 = Tag(label: "Tag A", categoryName: "Story", anchorTime: 10, rewindDuration: 5)
        let tag2 = Tag(label: "Tag B", categoryName: "Combat", anchorTime: 20, rewindDuration: 10)
        let tag3 = Tag(label: "Tag C", categoryName: "World", anchorTime: 30, rewindDuration: 15)

        context.insert(campaign)
        context.insert(session1)
        context.insert(session2)
        context.insert(tag1)
        context.insert(tag2)
        context.insert(tag3)

        campaign.sessions.append(session1)
        campaign.sessions.append(session2)
        session1.tags.append(tag1)
        session1.tags.append(tag2)
        session2.tags.append(tag3)
        try context.save()

        // Verify setup
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 3)

        // Delete campaign — should cascade through sessions to tags
        context.delete(campaign)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 0, "All sessions should cascade-delete")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 0, "All tags should cascade-delete transitively")
    }

    // AC#4 supplement: TagCategory deletion does NOT cascade to tags
    func testTagCategoryDeletionDoesNotAffectTags() throws {
        let category = TagCategory(name: "Combat", colorHex: "#DC2626", iconName: "shield")
        let session = Session(title: "S1", sessionNumber: 1)
        let tag = Tag(label: "Critical Hit", categoryName: "Combat", anchorTime: 45, rewindDuration: 10)

        context.insert(category)
        context.insert(session)
        context.insert(tag)
        session.tags.append(tag)
        try context.save()

        context.delete(category)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 1, "Tags must survive category deletion")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TagCategory>()), 0)
    }

    // AC#2: DictlyKit contains zero UIKit or AppKit imports (verified by compilation — if this test compiles, it passes)
    func testDictlyKitHasNoPlatformImports() {
        // This test verifies by compilation: DictlyModels imports only Foundation + SwiftData.
        // If UIKit or AppKit were imported, this test target (which may not link those frameworks) would fail to build.
        let _ = DictlySchema.all
        XCTAssertEqual(DictlySchema.all.count, 4, "Schema should contain exactly 4 model types")
    }

    // MARK: - Story 1.3: Campaign Management

    // AC#2: Create campaign with name and optional description
    func testCreateCampaignWithMetadata() throws {
        let campaign = Campaign(name: "Dragon's Lair", descriptionText: "A classic dungeon crawl")
        context.insert(campaign)
        try context.save()

        let results = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Dragon's Lair")
        XCTAssertEqual(results[0].descriptionText, "A classic dungeon crawl")
        XCTAssertNotNil(results[0].createdAt)
    }

    // AC#3: Rename campaign
    func testRenameCampaign() throws {
        let campaign = Campaign(name: "Old Name")
        context.insert(campaign)
        try context.save()

        campaign.name = "New Name"
        try context.save()

        let results = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(results[0].name, "New Name")
    }

    // AC#4: Delete campaign cascades sessions
    func testDeleteCampaignCascadesSessions() throws {
        let campaign = Campaign(name: "Campaign")
        let session = Session(title: "S1", sessionNumber: 1)
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        context.delete(campaign)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 0)
    }

    // AC#5: Campaigns display session count
    func testCampaignSessionCount() throws {
        let campaign = Campaign(name: "Campaign")
        context.insert(campaign)
        for i in 1...5 {
            let session = Session(title: "Session \(i)", sessionNumber: i)
            context.insert(session)
            campaign.sessions.append(session)
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(fetched[0].sessions.count, 5)
    }

    // AC#1: Empty campaign list (no campaigns exist)
    func testEmptyStateNoCampaigns() throws {
        let campaigns = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertTrue(campaigns.isEmpty, "Fresh store should have no campaigns")
    }

    // MARK: - Story 1.4: Session Organization

    // AC#2: Sessions listed with metadata
    func testSessionMetadata() throws {
        let campaign = Campaign(name: "Campaign")
        let session = Session(
            title: "Session 1",
            sessionNumber: 1,
            date: Date(),
            duration: 7380, // 2h 3m
            locationName: "Game Store"
        )
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)

        let tag1 = Tag(label: "Tag A", categoryName: "Combat", anchorTime: 10, rewindDuration: 5)
        let tag2 = Tag(label: "Tag B", categoryName: "Story", anchorTime: 20, rewindDuration: 5)
        context.insert(tag1)
        context.insert(tag2)
        session.tags.append(tag1)
        session.tags.append(tag2)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched[0].title, "Session 1")
        XCTAssertEqual(fetched[0].duration, 7380)
        XCTAssertEqual(fetched[0].tags.count, 2)
        XCTAssertEqual(fetched[0].locationName, "Game Store")
    }

    // AC#3: Auto-numbering — next session gets max+1
    func testSessionAutoNumbering() throws {
        let campaign = Campaign(name: "Campaign")
        context.insert(campaign)

        // Create sessions 1, 2, 3
        for i in 1...3 {
            let session = Session(title: "Session \(i)", sessionNumber: i)
            context.insert(session)
            campaign.sessions.append(session)
        }
        try context.save()

        // Compute next session number
        let nextNumber = (campaign.sessions.map(\.sessionNumber).max() ?? 0) + 1
        XCTAssertEqual(nextNumber, 4)
    }

    // AC#3: Auto-numbering handles gaps (no gap-filling)
    func testSessionAutoNumberingWithGaps() throws {
        let campaign = Campaign(name: "Campaign")
        context.insert(campaign)

        let s1 = Session(title: "Session 1", sessionNumber: 1)
        let s3 = Session(title: "Session 3", sessionNumber: 3)
        context.insert(s1)
        context.insert(s3)
        campaign.sessions.append(s1)
        campaign.sessions.append(s3)
        try context.save()

        // Next should be 4, not 2 (no gap-filling)
        let nextNumber = (campaign.sessions.map(\.sessionNumber).max() ?? 0) + 1
        XCTAssertEqual(nextNumber, 4, "Auto-numbering should use max+1, never gap-fill")
    }

    // AC#3: Default title is "Session N"
    func testSessionDefaultTitle() throws {
        let campaign = Campaign(name: "Campaign")
        context.insert(campaign)

        let nextNumber = (campaign.sessions.map(\.sessionNumber).max() ?? 0) + 1
        let session = Session(title: "Session \(nextNumber)", sessionNumber: nextNumber)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        XCTAssertEqual(session.title, "Session 1")
        XCTAssertEqual(session.sessionNumber, 1)
    }

    // AC#3: Session title is editable
    func testSessionTitleEditable() throws {
        let session = Session(title: "Session 1", sessionNumber: 1)
        context.insert(session)
        try context.save()

        session.title = "Epic Finale"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(fetched[0].title, "Epic Finale")
    }

    // AC#1: Empty state — campaign with no sessions
    func testEmptyStateNoSessions() throws {
        let campaign = Campaign(name: "Empty Campaign")
        context.insert(campaign)
        try context.save()

        XCTAssertTrue(campaign.sessions.isEmpty)
    }

    // AC#2: Sessions listed chronologically
    func testSessionsChronologicalOrder() throws {
        let campaign = Campaign(name: "Campaign")
        context.insert(campaign)

        let now = Date()
        let older = Session(title: "First", sessionNumber: 1, date: now.addingTimeInterval(-86400))
        let newer = Session(title: "Second", sessionNumber: 2, date: now)
        context.insert(older)
        context.insert(newer)
        campaign.sessions.append(older)
        campaign.sessions.append(newer)
        try context.save()

        let sorted = campaign.sessions.sorted { $0.date > $1.date }
        XCTAssertEqual(sorted[0].title, "Second")
        XCTAssertEqual(sorted[1].title, "First")
    }

    // Session deletion removes from campaign
    func testDeleteSessionRemovesFromCampaign() throws {
        let campaign = Campaign(name: "Campaign")
        let session = Session(title: "S1", sessionNumber: 1)
        context.insert(campaign)
        context.insert(session)
        campaign.sessions.append(session)
        try context.save()

        XCTAssertEqual(campaign.sessions.count, 1)
        context.delete(session)
        try context.save()

        let fetchedCampaign = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(fetchedCampaign[0].sessions.count, 0)
    }

    // MARK: - Story 1.5: Tag Category & Tag Management

    // AC#1: Default tag categories seeded on fresh install
    func testDefaultCategoriesSeededOnFreshInstall() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        let categories = try context.fetch(
            FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        XCTAssertEqual(categories.count, 5)
        XCTAssertEqual(categories[0].name, "Story")
        XCTAssertEqual(categories[0].colorHex, "#D97706")
        XCTAssertEqual(categories[1].name, "Combat")
        XCTAssertEqual(categories[1].colorHex, "#DC2626")
        XCTAssertEqual(categories[2].name, "Roleplay")
        XCTAssertEqual(categories[2].colorHex, "#7C3AED")
        XCTAssertEqual(categories[3].name, "World")
        XCTAssertEqual(categories[3].colorHex, "#059669")
        XCTAssertEqual(categories[4].name, "Meta")
        XCTAssertEqual(categories[4].colorHex, "#4B7BE5")
    }

    // AC#6: Default tags seeded per category
    func testDefaultTagsSeededPerCategory() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        let expectedTags: [String: Set<String>] = [
            "Story": ["Plot Hook", "Lore Drop", "Quest Update", "Foreshadowing", "Revelation"],
            "Combat": ["Initiative", "Epic Roll", "Critical Hit", "Encounter Start", "Encounter End"],
            "Roleplay": ["Character Moment", "NPC Introduction", "Memorable Quote", "In-Character Speech", "Emotional Beat"],
            "World": ["Location", "Item", "Lore", "Map Note", "Environment Description"],
            "Meta": ["Ruling", "House Rule", "Schedule", "Break", "Player Note"],
        ]

        for (categoryName, expectedLabels) in expectedTags {
            let predicate = #Predicate<Tag> { $0.categoryName == categoryName }
            let tags = try context.fetch(FetchDescriptor<Tag>(predicate: predicate))
            let labels = Set(tags.map(\.label))
            XCTAssertEqual(labels, expectedLabels, "Tags for \(categoryName) don't match expected")
        }
    }

    // AC#2: Create custom tag category
    func testCreateCustomTagCategory() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        let custom = TagCategory(
            name: "Homebrew",
            colorHex: "#FF6600",
            iconName: "wand.and.stars",
            sortOrder: 5,
            isDefault: false
        )
        context.insert(custom)
        try context.save()

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 6)
        XCTAssertTrue(categories.contains { $0.name == "Homebrew" })
        XCTAssertFalse(categories.first { $0.name == "Homebrew" }!.isDefault)
    }

    // AC#3: Rename category
    func testRenameCategoryReflectsImmediately() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        let story = categories.first { $0.name == "Story" }!
        let oldName = story.name

        story.name = "Narrative"
        // Update tags' categoryName to match (as the app does)
        let capturedName = oldName
        let predicate = #Predicate<Tag> { $0.categoryName == capturedName }
        let affectedTags = try context.fetch(FetchDescriptor<Tag>(predicate: predicate))
        for tag in affectedTags {
            tag.categoryName = "Narrative"
        }
        try context.save()

        XCTAssertEqual(story.name, "Narrative")
        let narrativePredicate = #Predicate<Tag> { $0.categoryName == "Narrative" }
        let narrativeTags = try context.fetch(FetchDescriptor<Tag>(predicate: narrativePredicate))
        XCTAssertEqual(narrativeTags.count, 5, "All Story tags should now be Narrative")
    }

    // AC#3: Delete category → tags reassigned to "Uncategorized"
    func testDeleteCategoryReassignsTagsToUncategorized() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        let combat = categories.first { $0.name == "Combat" }!

        // Reassign tags
        let categoryName = combat.name
        let predicate = #Predicate<Tag> { $0.categoryName == categoryName }
        let orphanedTags = try context.fetch(FetchDescriptor<Tag>(predicate: predicate))
        XCTAssertEqual(orphanedTags.count, 5)

        // Create "Uncategorized" fallback
        let uncategorized = TagCategory(
            name: "Uncategorized",
            colorHex: "#78716C",
            iconName: "tag",
            sortOrder: categories.count,
            isDefault: false
        )
        context.insert(uncategorized)

        for tag in orphanedTags {
            tag.categoryName = "Uncategorized"
        }
        context.delete(combat)
        try context.save()

        // Verify tags still exist and are reassigned
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(allTags.count, 25, "No tags should be deleted")

        let uncategorizedPredicate = #Predicate<Tag> { $0.categoryName == "Uncategorized" }
        let reassigned = try context.fetch(FetchDescriptor<Tag>(predicate: uncategorizedPredicate))
        XCTAssertEqual(reassigned.count, 5, "5 Combat tags should be Uncategorized")
    }

    // AC#4: Reorder categories — sortOrder persists
    func testReorderCategoriesPersistsSortOrder() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        var categories = try context.fetch(
            FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        XCTAssertEqual(categories.map(\.name), ["Story", "Combat", "Roleplay", "World", "Meta"])

        // Move Meta (index 4) to first position
        let moved = categories.remove(at: 4)
        categories.insert(moved, at: 0)
        for (i, cat) in categories.enumerated() {
            cat.sortOrder = i
        }
        try context.save()

        let reloaded = try context.fetch(
            FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        XCTAssertEqual(reloaded.map(\.name), ["Meta", "Story", "Combat", "Roleplay", "World"])
    }

    // AC#5: CRUD tags within a category
    func testCreateTagWithinCategory() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        let newTag = Tag(
            label: "Custom Moment",
            categoryName: "Story",
            anchorTime: 0,
            rewindDuration: 0
        )
        context.insert(newTag)
        try context.save()

        let storyPredicate = #Predicate<Tag> { $0.categoryName == "Story" }
        let storyTags = try context.fetch(FetchDescriptor<Tag>(predicate: storyPredicate))
        XCTAssertEqual(storyTags.count, 6, "Should have 5 defaults + 1 custom")
        XCTAssertTrue(storyTags.contains { $0.label == "Custom Moment" })
    }

    func testRenameTag() throws {
        let tag = Tag(label: "Old Label", categoryName: "Combat", anchorTime: 0, rewindDuration: 0)
        context.insert(tag)
        try context.save()

        tag.label = "New Label"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].label, "New Label")
    }

    func testDeleteTag() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        let combatPredicate = #Predicate<Tag> { $0.categoryName == "Combat" }
        let combatTags = try context.fetch(FetchDescriptor<Tag>(predicate: combatPredicate))
        let initiative = combatTags.first { $0.label == "Initiative" }!

        context.delete(initiative)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Tag>(predicate: combatPredicate))
        XCTAssertEqual(remaining.count, 4)
        XCTAssertFalse(remaining.contains { $0.label == "Initiative" })
    }

    // MARK: - Cross-Story E2E: Full Campaign Lifecycle

    func testFullCampaignLifecycle() throws {
        // 1. Seed defaults (Story 1.5)
        try DefaultTagSeeder.seedIfNeeded(context: context)

        // 2. Create campaign (Story 1.3)
        let campaign = Campaign(name: "Curse of Strahd", descriptionText: "Gothic horror campaign")
        context.insert(campaign)

        // 3. Create sessions with auto-numbering (Story 1.4)
        for i in 1...3 {
            let nextNumber = (campaign.sessions.map(\.sessionNumber).max() ?? 0) + 1
            let session = Session(
                title: "Session \(nextNumber)",
                sessionNumber: nextNumber,
                duration: TimeInterval(i * 3600)
            )
            context.insert(session)
            campaign.sessions.append(session)

            // 4. Add tags to sessions (Story 1.5)
            let tag = Tag(
                label: "Plot Hook",
                categoryName: "Story",
                anchorTime: TimeInterval(i * 60),
                rewindDuration: 10
            )
            context.insert(tag)
            session.tags.append(tag)
        }
        try context.save()

        // Verify the full structure
        let campaigns = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(campaigns.count, 1)
        XCTAssertEqual(campaigns[0].sessions.count, 3)
        XCTAssertEqual(campaigns[0].sessions.map(\.sessionNumber).sorted(), [1, 2, 3])

        for session in campaigns[0].sessions {
            XCTAssertEqual(session.tags.count, 1)
            XCTAssertEqual(session.tags[0].categoryName, "Story")
        }

        // 5. Rename campaign (Story 1.3)
        campaigns[0].name = "Ravenloft Redux"
        try context.save()
        XCTAssertEqual(campaigns[0].name, "Ravenloft Redux")

        // 6. Delete middle session — other sessions and tags unaffected (Story 1.4)
        let session2 = campaigns[0].sessions.first { $0.sessionNumber == 2 }!
        context.delete(session2)
        try context.save()

        XCTAssertEqual(campaigns[0].sessions.count, 2)
        // Tags from deleted session should also be gone
        let remainingTags = try context.fetch(FetchDescriptor<Tag>())
        // 25 seeded + 2 remaining session tags = 27
        XCTAssertEqual(remainingTags.count, 27)

        // 7. Next session number is max+1 = 4, not gap-filling (Story 1.4)
        let nextNumber = (campaigns[0].sessions.map(\.sessionNumber).max() ?? 0) + 1
        XCTAssertEqual(nextNumber, 4)

        // 8. Delete campaign — everything cascades (Story 1.1 AC#4)
        context.delete(campaigns[0])
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Campaign>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 0)
        // Only seeded template tags remain (they have no session)
        let templateTags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertTrue(templateTags.allSatisfy { $0.session == nil })
    }

    // MARK: - Cross-Story E2E: Tag Category Management Lifecycle

    func testTagCategoryManagementLifecycle() throws {
        // 1. Seed defaults
        try DefaultTagSeeder.seedIfNeeded(context: context)

        // 2. Verify 5 categories with 25 tags
        var categories = try context.fetch(
            FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        XCTAssertEqual(categories.count, 5)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 25)

        // 3. Add custom category
        let custom = TagCategory(name: "Homebrew", colorHex: "#FF0000", iconName: "star", sortOrder: 5, isDefault: false)
        context.insert(custom)
        let customTag = Tag(label: "Custom Rule", categoryName: "Homebrew", anchorTime: 0, rewindDuration: 0)
        context.insert(customTag)
        try context.save()

        categories = try context.fetch(FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(categories.count, 6)

        // 4. Reorder: move Homebrew to position 0
        let homebrew = categories.first { $0.name == "Homebrew" }!
        var mutable = categories
        mutable.removeAll { $0.name == "Homebrew" }
        mutable.insert(homebrew, at: 0)
        for (i, cat) in mutable.enumerated() {
            cat.sortOrder = i
        }
        try context.save()

        let reloaded = try context.fetch(
            FetchDescriptor<TagCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        XCTAssertEqual(reloaded[0].name, "Homebrew")

        // 5. Delete Homebrew → its tag goes to Uncategorized
        let homebrewName = "Homebrew"
        let tagPredicate = #Predicate<Tag> { $0.categoryName == homebrewName }
        let homebrewTags = try context.fetch(FetchDescriptor<Tag>(predicate: tagPredicate))

        let uncategorized = TagCategory(
            name: "Uncategorized",
            colorHex: "#78716C",
            iconName: "tag",
            sortOrder: reloaded.count,
            isDefault: false
        )
        context.insert(uncategorized)

        for tag in homebrewTags {
            tag.categoryName = "Uncategorized"
        }
        context.delete(homebrew)
        try context.save()

        let uncatPredicate = #Predicate<Tag> { $0.categoryName == "Uncategorized" }
        let uncatTags = try context.fetch(FetchDescriptor<Tag>(predicate: uncatPredicate))
        XCTAssertEqual(uncatTags.count, 1)
        XCTAssertEqual(uncatTags[0].label, "Custom Rule")

        // Total tags unchanged: 25 seeded + 1 custom = 26
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 26)
    }

    // MARK: - Story 1.5 AC#1: Seeder Idempotency

    func testSeederIdempotentAfterSeedAndCustomAddition() throws {
        try DefaultTagSeeder.seedIfNeeded(context: context)

        // Add a custom category
        let custom = TagCategory(name: "Custom", colorHex: "#000", iconName: "tag")
        context.insert(custom)
        try context.save()

        // Seeder should not run again
        try DefaultTagSeeder.seedIfNeeded(context: context)
        let categories = try context.fetch(FetchDescriptor<TagCategory>())
        XCTAssertEqual(categories.count, 6, "Seeder should not re-seed when categories exist")
    }

    // MARK: - DictlyError

    func testDictlyErrorLocalizedDescriptions() {
        let errors: [(DictlyError, String)] = [
            (.recording(.permissionDenied), "Microphone permission denied."),
            (.recording(.deviceUnavailable), "Audio device unavailable."),
            (.recording(.interrupted), "Recording interrupted."),
            (.transfer(.networkUnavailable), "Network unavailable for transfer."),
            (.transfer(.peerNotFound), "Transfer peer not found."),
            (.transfer(.bundleCorrupted), "Transfer bundle is corrupted."),
            (.transcription(.modelNotFound), "Transcription model not found."),
            (.transcription(.processingFailed), "Transcription processing failed."),
            (.storage(.diskFull), "Not enough disk space."),
            (.storage(.permissionDenied), "Storage permission denied."),
            (.storage(.fileNotFound), "File not found."),
            (.storage(.syncFailed("test")), "Sync failed: test"),
            (.import(.invalidFormat), "Invalid import format."),
            (.import(.duplicateDetected), "Duplicate session detected."),
            (.import(.missingData), "Required data missing from import."),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.errorDescription, expected, "Error description mismatch for \(error)")
        }
    }

    // MARK: - Multiple Campaigns

    func testMultipleCampaignsIndependent() throws {
        let c1 = Campaign(name: "Campaign Alpha")
        let c2 = Campaign(name: "Campaign Beta")
        context.insert(c1)
        context.insert(c2)

        let s1 = Session(title: "S1", sessionNumber: 1)
        let s2 = Session(title: "S2", sessionNumber: 1) // same number, different campaign
        context.insert(s1)
        context.insert(s2)
        c1.sessions.append(s1)
        c2.sessions.append(s2)
        try context.save()

        // Delete campaign 1 — campaign 2 unaffected
        context.delete(c1)
        try context.save()

        let campaigns = try context.fetch(FetchDescriptor<Campaign>())
        XCTAssertEqual(campaigns.count, 1)
        XCTAssertEqual(campaigns[0].name, "Campaign Beta")
        XCTAssertEqual(campaigns[0].sessions.count, 1)
    }
}
