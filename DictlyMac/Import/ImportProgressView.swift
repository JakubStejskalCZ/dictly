import SwiftUI
import DictlyTheme

/// Top-of-window banner that reflects the current `ImportService.importState`.
///
/// Banner states:
/// - `.idle` → hidden (EmptyView)
/// - `.importing(progress:)` → "Importing session..." with progress bar
/// - `.completed(sessionTitle:)` → success banner, auto-dismisses after 3 seconds
/// - `.duplicate(sessionTitle:)` → "Session already exists" with Skip/Replace buttons
/// - `.failed(error:)` → error message with Retry button
struct ImportProgressView: View {
    @Environment(ImportService.self) private var importService

    var body: some View {
        switch importService.importState {
        case .idle:
            EmptyView()

        case .importing(let progress):
            importingBanner(progress: progress)
                .transition(.move(edge: .top).combined(with: .opacity))

        case .completed(let sessionTitle):
            completedBanner(sessionTitle: sessionTitle)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(3))
                    if case .completed = importService.importState {
                        importService.skipDuplicate()
                    }
                }

        case .duplicate(let sessionTitle):
            duplicateBanner(sessionTitle: sessionTitle)
                .transition(.move(edge: .top).combined(with: .opacity))

        case .failed(let error):
            failedBanner(error: error)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Banner Views

    @ViewBuilder
    private func importingBanner(progress: Double) -> some View {
        HStack(spacing: DictlySpacing.sm) {
            ProgressView(value: progress)
                .frame(maxWidth: 120)
                .accessibilityLabel("Import progress, \(Int(progress * 100)) percent")
            Text("Importing session...")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textPrimary)
            Spacer()
        }
        .padding(DictlySpacing.md)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
        .padding([.horizontal, .top], DictlySpacing.md)
    }

    @ViewBuilder
    private func completedBanner(sessionTitle: String) -> some View {
        HStack(spacing: DictlySpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DictlyColors.success)
                .accessibilityHidden(true)
            Text("Session imported successfully")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textPrimary)
            Spacer()
        }
        .padding(DictlySpacing.md)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
        .padding([.horizontal, .top], DictlySpacing.md)
        .accessibilityLabel("Session \(sessionTitle) imported successfully")
    }

    @ViewBuilder
    private func duplicateBanner(sessionTitle: String) -> some View {
        HStack(spacing: DictlySpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DictlyColors.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Session already exists")
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textPrimary)
                Text(sessionTitle)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
            Spacer()
            Button("Skip") {
                importService.skipDuplicate()
            }
            .accessibilityLabel("Skip duplicate, keep existing session")
            Button("Replace") {
                importService.replaceExistingDuplicate()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Replace existing session with imported one")
        }
        .padding(DictlySpacing.md)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
        .padding([.horizontal, .top], DictlySpacing.md)
        .accessibilityLabel("Session \(sessionTitle) already exists. Choose to skip or replace.")
    }

    @ViewBuilder
    private func failedBanner(error: Error) -> some View {
        HStack(spacing: DictlySpacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(DictlyColors.destructive)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Import failed")
                    .font(DictlyTypography.body)
                    .foregroundStyle(DictlyColors.textPrimary)
                Text(error.localizedDescription)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }
            Spacer()
            Button("Retry") {
                importService.retry()
            }
            .accessibilityLabel("Retry import")
        }
        .padding(DictlySpacing.md)
        .background(DictlyColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
        .padding([.horizontal, .top], DictlySpacing.md)
        .accessibilityLabel("Import failed: \(error.localizedDescription). Retry button available.")
    }
}
