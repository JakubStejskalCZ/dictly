import Foundation
import DictlyModels

public struct MarkdownExporter {

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
            lines.append("> \(summary)")
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

        let sortedSessions = campaign.sessions.sorted { $0.date < $1.date }

        if sortedSessions.isEmpty {
            lines.append("No sessions in this campaign.")
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy"
            for session in sortedSessions {
                let dateStr = dateFormatter.string(from: session.date)
                lines.append("## Session \(session.sessionNumber) — \(session.title) (\(dateStr))")
                lines.append("")
                lines.append(metadataLine(for: session))
                lines.append("")
                if let summary = session.summaryNote, !summary.isEmpty {
                    lines.append("> \(summary)")
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let dateStr = dateFormatter.string(from: session.date)
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
            let categoryTags = (grouped[category] ?? []).sorted { $0.anchorTime < $1.anchorTime }
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
                    lines.append("> Note: \(note)")
                }
                lines.append("")
            }
        }
    }

    private static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    private static func sanitizeFilename(_ name: String) -> String {
        name.replacingOccurrences(of: "[/:\\\\]", with: "-", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
