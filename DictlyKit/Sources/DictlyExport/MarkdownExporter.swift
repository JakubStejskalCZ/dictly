import Foundation
import DictlyModels

public struct MarkdownExporter {

    // MARK: - Static Formatters

    private static let metadataDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let campaignDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    // MARK: - Session Export

    public static func exportSession(_ session: Session) -> String {
        var lines: [String] = []

        // H1: session title
        lines.append("# Session \(session.sessionNumber) — \(session.title)")
        lines.append("")

        // Metadata line
        lines.append(metadataLine(for: session))
        lines.append("")

        // Summary note blockquote
        if let summary = session.summaryNote, !summary.isEmpty {
            appendBlockquote(summary, prefix: nil, into: &lines)
            lines.append("")
        }

        // Tags grouped by category
        appendTagSections(for: session.tags, headingLevel: 2, into: &lines)

        return lines.joined(separator: "\n")
    }

    // MARK: - Campaign Export

    public static func exportCampaign(_ campaign: Campaign) -> String {
        var lines: [String] = []

        // H1: campaign name
        lines.append("# \(campaign.name)")
        lines.append("")

        // Campaign description
        if !campaign.descriptionText.isEmpty {
            lines.append(campaign.descriptionText)
            lines.append("")
        }

        let sortedSessions = campaign.sessions.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.sessionNumber < $1.sessionNumber
        }

        if sortedSessions.isEmpty {
            lines.append("No sessions in this campaign.")
        } else {
            for session in sortedSessions {
                let dateStr = campaignDateFormatter.string(from: session.date)
                lines.append("## Session \(session.sessionNumber) — \(session.title) (\(dateStr))")
                lines.append("")
                lines.append(metadataLine(for: session))
                lines.append("")
                if let summary = session.summaryNote, !summary.isEmpty {
                    appendBlockquote(summary, prefix: nil, into: &lines)
                    lines.append("")
                }
                appendTagSections(for: session.tags, headingLevel: 3, into: &lines)
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Filename Suggestions

    public static func suggestedFilename(for session: Session) -> String {
        let sanitized = sanitizeFilename(session.title)
        return "Session \(session.sessionNumber) - \(sanitized).md"
    }

    public static func suggestedFilename(for campaign: Campaign) -> String {
        let sanitized = sanitizeFilename(campaign.name)
        return "Campaign - \(sanitized).md"
    }

    // MARK: - Private Helpers

    private static func metadataLine(for session: Session) -> String {
        let dateStr = metadataDateFormatter.string(from: session.date)
        let durationStr = formatTimestamp(session.duration)
        let tagCount = session.tags.count
        var parts = [
            "**Date:** \(dateStr)",
            "**Duration:** \(durationStr)",
            "**Tags:** \(tagCount)"
        ]
        if let location = session.locationName, !location.isEmpty {
            parts.append("**Location:** \(location)")
        }
        return parts.joined(separator: " | ")
    }

    /// Appends a multi-line blockquote, ensuring every continuation line starts with `> `.
    /// - Parameters:
    ///   - text: The content to blockquote (may contain newlines).
    ///   - prefix: Optional prefix for the first line only (e.g. `"Note: "`). Subsequent lines use `> `.
    private static func appendBlockquote(_ text: String, prefix: String?, into lines: inout [String]) {
        let textLines = text.components(separatedBy: "\n")
        for (i, line) in textLines.enumerated() {
            if i == 0 {
                lines.append("> \(prefix ?? "")\(line)")
            } else {
                lines.append("> \(line)")
            }
        }
    }

    private static func appendTagSections(
        for tags: [Tag],
        headingLevel: Int,
        into lines: inout [String]
    ) {
        let heading = String(repeating: "#", count: headingLevel)

        if tags.isEmpty {
            lines.append("*No tags recorded.*")
            lines.append("")
            return
        }

        // Group tags by categoryName
        var grouped: [String: [Tag]] = [:]
        for tag in tags {
            grouped[tag.categoryName, default: []].append(tag)
        }

        let sortedCategories = grouped.keys.sorted()
        for category in sortedCategories {
            let categoryTags = grouped[category]!.sorted { $0.anchorTime < $1.anchorTime }
            lines.append("\(heading) \(category)")
            lines.append("")
            for tag in categoryTags {
                let timestamp = formatTimestamp(tag.anchorTime)
                lines.append("**[\(timestamp)] \(tag.label)**")
                if let transcription = tag.transcription, !transcription.isEmpty {
                    lines.append(transcription)
                } else {
                    lines.append("(no transcription)")
                }
                if let note = tag.notes, !note.isEmpty {
                    appendBlockquote(note, prefix: "Note: ", into: &lines)
                }
                lines.append("")
            }
        }
    }

    private static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let sanitized = name
            .replacingOccurrences(of: "[/:\\\\?*\"<>|]", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "Untitled" : sanitized
    }
}
