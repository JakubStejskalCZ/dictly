import Foundation

/// A themed collection of tag categories and their template tags.
/// Packs are static definitions — not persisted in SwiftData.
public struct TagPack: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let iconName: String
    public let categories: [(name: String, colorHex: String, iconName: String)]
    public let tags: [String: [String]]
}

/// Registry of all available tag packs.
public enum TagPackRegistry {

    public static let all: [TagPack] = [ttrpg, podcast, meetings]

    public static let ttrpg = TagPack(
        id: "ttrpg",
        name: "TTRPG",
        description: "Tabletop RPG sessions — combat, roleplay, lore, and story beats",
        iconName: "dice",
        categories: [
            ("Story",    "#D97706", "book.pages"),
            ("Combat",   "#DC2626", "shield"),
            ("Roleplay", "#7C3AED", "theatermasks"),
            ("World",    "#059669", "globe"),
            ("Meta",     "#4B7BE5", "info.circle")
        ],
        tags: [
            "Story":    ["Plot Hook", "Lore Drop", "Quest Update", "Foreshadowing", "Revelation"],
            "Combat":   ["Initiative", "Epic Roll", "Critical Hit", "Encounter Start", "Encounter End"],
            "Roleplay": ["Character Moment", "NPC Introduction", "Memorable Quote", "In-Character Speech", "Emotional Beat"],
            "World":    ["Location", "Item", "Lore", "Map Note", "Environment Description"],
            "Meta":     ["Ruling", "House Rule", "Schedule", "Break", "Player Note"]
        ]
    )

    public static let podcast = TagPack(
        id: "podcast",
        name: "Podcast",
        description: "Podcast recording — topics, segments, highlights, and editing cues",
        iconName: "mic",
        categories: [
            ("Segment",   "#2563EB", "list.bullet"),
            ("Highlight", "#D97706", "star"),
            ("Edit",      "#DC2626", "scissors"),
            ("Guest",     "#7C3AED", "person.2"),
            ("Reference", "#059669", "link")
        ],
        tags: [
            "Segment":   ["Intro", "Topic Change", "Outro", "Ad Break", "Recap"],
            "Highlight": ["Great Quote", "Key Insight", "Funny Moment", "Hot Take", "Story"],
            "Edit":      ["Cut This", "Re-record", "Add Music", "Sound Effect", "Silence"],
            "Guest":     ["Guest Intro", "Guest Question", "Guest Story", "Follow-up", "Contact Info"],
            "Reference": ["Link", "Book", "Article", "Tool", "Show Notes"]
        ]
    )

    public static let meetings = TagPack(
        id: "meetings",
        name: "Meetings",
        description: "Meeting notes — decisions, actions, questions, and follow-ups",
        iconName: "calendar",
        categories: [
            ("Decision",  "#059669", "checkmark.seal"),
            ("Action",    "#2563EB", "arrow.right.circle"),
            ("Question",  "#D97706", "questionmark.circle"),
            ("Idea",      "#7C3AED", "lightbulb"),
            ("Follow-up", "#DC2626", "flag")
        ],
        tags: [
            "Decision":  ["Approved", "Rejected", "Deferred", "Consensus", "Owner Assigned"],
            "Action":    ["TODO", "Deadline Set", "Assigned To", "Blocked", "Completed"],
            "Question":  ["Open Question", "Answered", "Needs Research", "Parking Lot", "Offline"],
            "Idea":      ["Proposal", "Brainstorm", "Improvement", "New Feature", "Experiment"],
            "Follow-up": ["Next Meeting", "Email Required", "Document", "Review Needed", "Escalate"]
        ]
    )
}
