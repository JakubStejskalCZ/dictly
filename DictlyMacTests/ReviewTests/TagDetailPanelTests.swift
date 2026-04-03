import XCTest
@testable import DictlyMac
import SwiftData
import DictlyModels

// MARK: - TagDetailPanelTests
//
// Tests for Story 5.4: View & Edit Transcription Text.
// Covers: transcription display, inline editing, auto-save on blur, tag switching,
// empty-string preservation, and edge cases.
//
// Tests validate the SwiftData model layer and the commit logic mirroring
// TagDetailPanel's commitTranscription and onChange behaviour.
//
// Uses in-memory ModelContainer per project convention.
// Note: Mac test target requires dev signing certificate to run locally due to
// iCloud entitlement on the host app (pre-existing constraint from story 3.3).
// The test target builds cleanly (** TEST BUILD SUCCEEDED **) even without signing.

@MainActor
final class TagDetailPanelTests: XCTestCase {

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

    // MARK: - AC1: Selecting a tag with transcription displays transcription text

    func testTagWithTranscription_hasNonNilTranscription() throws {
        let tag = makeTag(label: "Dragon Fight", transcription: "The party attacked the dragon near the bridge.")
        context.insert(tag)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertNotNil(fetched[0].transcription)
        XCTAssertEqual(fetched[0].transcription, "The party attacked the dragon near the bridge.")
    }

    func testTagWithTranscription_bufferInitialisedFromModel() {
        // Simulates the onAppear / onChange(of: selectedTag?.uuid) buffer sync logic
        let tag = makeTag(label: "Story Moment", transcription: "Elara opened the ancient tome.")
        let buffer = tag.transcription ?? ""
        XCTAssertEqual(buffer, "Elara opened the ancient tome.")
    }

    func testTagWithNilTranscription_bufferInitialisedToEmpty() {
        // Tag without transcription → buffer should be empty (nil coalesced to "")
        let tag = makeTag(label: "No Transcription", transcription: nil)
        let buffer = tag.transcription ?? ""
        XCTAssertEqual(buffer, "")
    }

    // MARK: - AC2 & AC3: Editing transcription and auto-saving on blur

    func testCommitTranscriptionLogic_savesEditedText() throws {
        let tag = makeTag(label: "Combat", transcription: "Grim Thor charges forward.")
        context.insert(tag)

        // Simulate user editing and blur (commitTranscription logic)
        let editingTranscription = "Grimthor charges forward."
        if editingTranscription != (tag.transcription ?? "") {
            tag.transcription = editingTranscription
        }

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].transcription, "Grimthor charges forward.")
    }

    func testCommitTranscriptionLogic_noOpWhenUnchanged() throws {
        let originalText = "Elara casts a fireball."
        let tag = makeTag(label: "Magic", transcription: originalText)
        context.insert(tag)

        // Simulate blur with no change — guard should short-circuit
        let editingTranscription = originalText
        if editingTranscription != (tag.transcription ?? "") {
            tag.transcription = editingTranscription
        }

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].transcription, originalText, "No write should occur when text is unchanged")
    }

    func testCommitTranscription_persistsMultipleEdits() throws {
        let tag = makeTag(label: "Roleplay", transcription: "First transcription.")
        context.insert(tag)

        tag.transcription = "Second edit."
        tag.transcription = "Third and final edit."

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(fetched[0].transcription, "Third and final edit.")
    }

    // MARK: - AC4: Tag without transcription shows placeholder state

    func testTagWithoutTranscription_hasNilTranscription() throws {
        let tag = makeTag(label: "Untranscribed Tag", transcription: nil)
        context.insert(tag)

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertNil(fetched[0].transcription, "Tag without transcription should have nil — shows Transcribe button in UI")
    }

    func testTagNilTranscription_distinctFromEmptyString() throws {
        let nilTag = makeTag(label: "Never Transcribed", transcription: nil)
        let emptyTag = makeTag(label: "User Cleared", transcription: "")
        context.insert(nilTag)
        context.insert(emptyTag)

        let fetched = try context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.label)]))
        let neverTag = fetched.first { $0.label == "Never Transcribed" }!
        let clearedTag = fetched.first { $0.label == "User Cleared" }!

        XCTAssertNil(neverTag.transcription, "nil means never transcribed — shows Transcribe button")
        XCTAssertNotNil(clearedTag.transcription, "empty string means user cleared — shows editable TextEditor")
        XCTAssertEqual(clearedTag.transcription, "")
    }

    // MARK: - AC3 (edge): Switching tags commits pending edit to previous tag

    func testTagSwitch_committsPendingEditToOldTag() throws {
        let tagA = makeTag(label: "Tag A", transcription: "Original text for A.")
        let tagB = makeTag(label: "Tag B", transcription: "Text for B.")
        context.insert(tagA)
        context.insert(tagB)

        // Simulate: user is editing tagA's transcription, then switches to tagB.
        // The onChange(of: selectedTag?.uuid) handler writes editingTranscription to the old tag.
        let editingTranscription = "Edited text for A."
        let oldUUID = tagA.uuid

        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.uuid == oldUUID })
        if let oldTag = try? context.fetch(descriptor).first {
            if editingTranscription != (oldTag.transcription ?? "") {
                oldTag.transcription = editingTranscription
            }
        }

        let fetched = try context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.label)]))
        let fetchedA = fetched.first { $0.label == "Tag A" }!
        let fetchedB = fetched.first { $0.label == "Tag B" }!

        XCTAssertEqual(fetchedA.transcription, "Edited text for A.", "Pending edit committed before tag switch")
        XCTAssertEqual(fetchedB.transcription, "Text for B.", "Tag B should be unchanged")
    }

    func testTagSwitch_newTagBufferLoadsCorrectTranscription() {
        // Simulates buffer reload logic: editingTranscription = tag.transcription ?? ""
        let tagA = makeTag(label: "Tag A", transcription: "Text A.")
        let tagB = makeTag(label: "Tag B", transcription: "Text B.")

        // Simulate switching from tagA to tagB
        let bufferAfterSwitch = tagB.transcription ?? ""
        XCTAssertEqual(bufferAfterSwitch, "Text B.")
    }

    func testTagSwitch_toTagWithoutTranscriptionEmptiesBuffer() {
        let tagWithTranscription = makeTag(label: "Tag A", transcription: "Has text.")
        let tagWithoutTranscription = makeTag(label: "Tag B", transcription: nil)

        _ = tagWithTranscription
        let bufferAfterSwitch = tagWithoutTranscription.transcription ?? ""
        XCTAssertEqual(bufferAfterSwitch, "")
    }

    // MARK: - Edge case: Clearing all text saves empty string (not nil)

    func testClearingTranscriptionText_savesEmptyString() throws {
        let tag = makeTag(label: "Tag", transcription: "Some text.")
        context.insert(tag)

        // Simulate user clearing all text — commitTranscription writes "" not nil
        let editingTranscription = ""
        if editingTranscription != (tag.transcription ?? "") {
            tag.transcription = editingTranscription
        }

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertNotNil(fetched[0].transcription, "Cleared transcription should be empty string, not nil")
        XCTAssertEqual(fetched[0].transcription, "")
    }

    func testClearingTranscription_doesNotRevertToNil() throws {
        let tag = makeTag(label: "Cleared Tag", transcription: "Original.")
        context.insert(tag)

        tag.transcription = ""

        let fetched = try context.fetch(FetchDescriptor<Tag>())
        // empty string ≠ nil: nil means "never transcribed", "" means "user cleared it"
        XCTAssertFalse(fetched[0].transcription == nil, "Cleared text must not revert to nil")
    }

    // MARK: - Edge case: Batch transcription update visible on next selection

    func testBatchTranscriptionUpdate_visibleWhenTagSelected() {
        // Simulates batch transcription writing to tag.transcription while user is NOT on that tag.
        // When the user later selects the tag, the buffer syncs from tag.transcription.
        let tag = makeTag(label: "Background Tag", transcription: nil)

        // Batch transcription completes and writes to model
        tag.transcription = "Auto-transcribed text."

        // User now selects this tag — buffer initialises from current model value
        let bufferOnSelect = tag.transcription ?? ""
        XCTAssertEqual(bufferOnSelect, "Auto-transcribed text.")
    }

    // MARK: - Transcription model persistence

    func testTranscriptionPersists_afterMultipleContextFetches() throws {
        let tag = makeTag(label: "Persistent Tag", transcription: nil)
        context.insert(tag)

        tag.transcription = "Whisper output for this segment."

        let firstFetch = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(firstFetch[0].transcription, "Whisper output for this segment.")

        tag.transcription = "Corrected: Whisper output for this segment."

        let secondFetch = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(secondFetch[0].transcription, "Corrected: Whisper output for this segment.")
    }

    func testTranscription_initiallyNilOnNewTag() {
        let tag = makeTag(label: "Brand New Tag", transcription: nil)
        XCTAssertNil(tag.transcription, "Newly created tags have nil transcription — shows Transcribe button")
    }

    // MARK: - AC4: "Captures from" timestamp (Story 7.2)

    func testCapturesFrom_tagWithRewindDuration_captureStartIsAnchorMinusRewind() {
        // Tag placed 10 seconds before the anchor (rewind capture)
        let tag = makeTag(label: "Ambush", transcription: nil, anchorTime: 83, rewindDuration: 10)
        // captureStart = anchorTime - rewindDuration = 83 - 10 = 73
        let captureStart = max(0, tag.anchorTime - tag.rewindDuration)
        XCTAssertEqual(captureStart, 73, "Capture-start time should be anchorTime - rewindDuration")
    }

    func testCapturesFrom_retroactiveTag_rewindDurationIsZero() {
        // Retroactive tags have rewindDuration == 0 — no "captures from" line shown
        let tag = makeTag(label: "Retroactive", transcription: nil, anchorTime: 120, rewindDuration: 0)
        XCTAssertEqual(tag.rewindDuration, 0, "Retroactive tags must have rewindDuration == 0")
        // Verify the condition used in the view: rewindDuration > 0 is false → no second line
        XCTAssertFalse(tag.rewindDuration > 0, "rewindDuration > 0 must be false for retroactive tags")
    }

    func testCapturesFrom_showsSecondLine_onlyWhenRewindDurationPositive() {
        let rewindTag = makeTag(label: "Rewind Tag", transcription: nil, anchorTime: 60, rewindDuration: 15)
        let retroTag  = makeTag(label: "Retro Tag",  transcription: nil, anchorTime: 60, rewindDuration: 0)
        XCTAssertTrue(rewindTag.rewindDuration > 0, "Rewind tag should show captures-from line")
        XCTAssertFalse(retroTag.rewindDuration > 0, "Retroactive tag should not show captures-from line")
    }

    func testCapturesFrom_captureStartClampedToZero_whenRewindExceedsAnchor() {
        // Edge case: rewindDuration > anchorTime → clamped to 0
        let tag = makeTag(label: "Very Early Tag", transcription: nil, anchorTime: 5, rewindDuration: 30)
        let captureStart = max(0, tag.anchorTime - tag.rewindDuration)
        XCTAssertEqual(captureStart, 0, "Capture-start time must not go negative")
    }

    // MARK: - Helpers

    private func makeTag(
        label: String,
        transcription: String?,
        categoryName: String = "Story",
        anchorTime: TimeInterval = 0,
        rewindDuration: TimeInterval = 0
    ) -> Tag {
        let tag = Tag(
            uuid: UUID(),
            label: label,
            categoryName: categoryName,
            anchorTime: anchorTime,
            rewindDuration: rewindDuration
        )
        tag.transcription = transcription
        return tag
    }
}
