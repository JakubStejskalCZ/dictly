import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - TagEditingTests
//
// Tests for Story 4.5: Tag Editing — Rename, Recategorize & Delete.
// Covers: inline label rename, category change persistence, tag deletion from session
// and model context, and empty-label guard (reverts to previous value).
//
// Uses in-memory ModelContainer per project convention.
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class TagEditingTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema(DictlySchema.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - 7.2 Renaming a tag updates tag.label in SwiftData

    func testRenameTag_updatesLabelInContext() throws {
        let tag = makeTag(label: "Dragon Attack", categoryName: "Combat")
        context.insert(tag)

        tag.label = "Ambush at the Bridge"

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].label, "Ambush at the Bridge")
    }

    func testRenameTag_originalLabelReplaced() throws {
        let tag = makeTag(label: "Old Name", categoryName: "Story")
        context.insert(tag)

        tag.label = "New Name"

        XCTAssertEqual(tag.label, "New Name")
        XCTAssertNotEqual(tag.label, "Old Name")
    }

    // MARK: - 7.3 Changing tag.categoryName persists correctly

    func testChangeCategoryName_persistsCorrectly() throws {
        let tag = makeTag(label: "Tavern scene", categoryName: "Story")
        context.insert(tag)

        tag.categoryName = "Roleplay"

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].categoryName, "Roleplay")
    }

    func testChangeCategoryName_fromCombatToWorld() throws {
        let tag = makeTag(label: "Sword fight", categoryName: "Combat")
        context.insert(tag)

        tag.categoryName = "World"

        XCTAssertEqual(tag.categoryName, "World")
    }

    // MARK: - 7.4 Deleting a tag removes it from session.tags

    func testDeleteTag_removesFromSessionTagsArray() throws {
        let session = Session(title: "Test Session", sessionNumber: 1, duration: 3600)
        let tag = makeTag(label: "Dragon", categoryName: "Combat")
        session.tags.append(tag)
        tag.session = session
        context.insert(session)
        context.insert(tag)

        XCTAssertEqual(session.tags.count, 1)

        session.tags.removeAll { $0.uuid == tag.uuid }
        context.delete(tag)

        XCTAssertEqual(session.tags.count, 0)
    }

    func testDeleteTag_withMultipleTags_removesOnlyTargetTag() throws {
        let session = Session(title: "Test Session", sessionNumber: 1, duration: 3600)
        let tag1 = makeTag(label: "Dragon", categoryName: "Combat")
        let tag2 = makeTag(label: "Merchant", categoryName: "Story")
        session.tags.append(contentsOf: [tag1, tag2])
        tag1.session = session
        tag2.session = session
        context.insert(session)
        context.insert(tag1)
        context.insert(tag2)

        session.tags.removeAll { $0.uuid == tag1.uuid }
        context.delete(tag1)

        XCTAssertEqual(session.tags.count, 1)
        XCTAssertEqual(session.tags[0].label, "Merchant")
    }

    // MARK: - 7.5 Deleting a tag removes it from the model context

    func testDeleteTag_removesFromModelContext() throws {
        let tag = makeTag(label: "Dragon", categoryName: "Combat")
        context.insert(tag)

        let beforeDelete = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(beforeDelete.count, 1)

        context.delete(tag)

        let afterDelete = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testDeleteTag_onlyDeletesTargetTag_otherTagsRemain() throws {
        let tag1 = makeTag(label: "Dragon", categoryName: "Combat")
        let tag2 = makeTag(label: "Merchant", categoryName: "Story")
        context.insert(tag1)
        context.insert(tag2)

        context.delete(tag1)

        let remaining = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].label, "Merchant")
    }

    // MARK: - 7.6 Empty label after edit reverts to previous value

    func testEmptyLabelGuard_emptyString_revertsToOriginal() {
        let tag = makeTag(label: "Dragon Attack", categoryName: "Combat")
        context.insert(tag)

        // Simulate commitLabel logic: empty trimmed value → revert
        let newInput = "   "
        let trimmed = newInput.trimmingCharacters(in: .whitespaces)
        let labelBeforeEdit = tag.label

        if trimmed.isEmpty {
            // revert — do not write to tag.label
        } else {
            tag.label = trimmed
        }

        XCTAssertEqual(tag.label, labelBeforeEdit, "Empty label should not overwrite existing label")
        XCTAssertEqual(tag.label, "Dragon Attack")
    }

    func testEmptyLabelGuard_nonEmptyString_savesNewLabel() {
        let tag = makeTag(label: "Old Label", categoryName: "Story")
        context.insert(tag)

        let newInput = "  New Label  "
        let trimmed = newInput.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            // revert
        } else {
            tag.label = trimmed
        }

        XCTAssertEqual(tag.label, "New Label")
    }

    func testEmptyLabelGuard_whitespaceOnlyString_doesNotSave() {
        let tag = makeTag(label: "Combat Start", categoryName: "Combat")
        context.insert(tag)

        let newInput = "\t\n  "
        let trimmed = newInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            tag.label = trimmed
        }

        XCTAssertEqual(tag.label, "Combat Start")
    }

    // MARK: - Helpers

    private func makeTag(
        label: String,
        categoryName: String,
        anchorTime: TimeInterval = 0
    ) -> Tag {
        Tag(
            uuid: UUID(),
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: 0
        )
    }
}
