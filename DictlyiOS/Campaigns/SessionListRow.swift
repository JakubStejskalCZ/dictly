import SwiftUI
import DictlyModels
import DictlyTheme

struct SessionListRow: View {
    let session: Session

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.xs) {
            Text(session.title)
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textPrimary)
            HStack(spacing: DictlySpacing.sm) {
                Text(Self.dateFormatter.string(from: session.date))
                Text("·")
                Text(formatDuration(session.duration))
                Text("·")
                Text(tagCountLabel)
                if let locationName = session.locationName {
                    Text("·")
                    Text(locationName)
                }
            }
            .font(DictlyTypography.caption)
            .foregroundStyle(DictlyColors.textSecondary)
        }
        .padding(.vertical, DictlySpacing.xs)
    }

    // MARK: - Helpers

    private var tagCountLabel: String {
        let count = session.tags.count
        return "\(count) \(count == 1 ? "tag" : "tags")"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
