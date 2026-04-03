import SwiftUI
import AppKit
import UniformTypeIdentifiers
import UserNotifications
import OSLog
import DictlyModels
import DictlyExport
import DictlyTheme

private let logger = Logger(subsystem: "com.dictly.mac", category: "export")

struct ExportSheet: View {
    let session: Session
    @Binding var isPresented: Bool

    @State private var exportError: String? = nil

    private var campaign: Campaign? { session.campaign }

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.md) {
            // Header
            Text("Export as Markdown")
                .font(DictlyTypography.h3)
                .foregroundStyle(DictlyColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Choose what to export:")
                .font(DictlyTypography.body)
                .foregroundStyle(DictlyColors.textSecondary)

            // Export options
            VStack(spacing: DictlySpacing.sm) {
                Button {
                    exportSession()
                } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Session")
                                .font(DictlyTypography.body)
                            Text("Session \(session.sessionNumber) — \(session.title)")
                                .font(DictlyTypography.caption)
                                .foregroundStyle(DictlyColors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(DictlySpacing.sm)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Export session as Markdown")

                if let campaign {
                    Button {
                        exportCampaign(campaign)
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export Campaign")
                                    .font(DictlyTypography.body)
                                Text(campaign.name)
                                    .font(DictlyTypography.caption)
                                    .foregroundStyle(DictlyColors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(DictlySpacing.sm)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Export campaign \(campaign.name) as Markdown")
                }
            }

            // Inline error display
            if let exportError {
                Text(exportError)
                    .font(DictlyTypography.caption)
                    .foregroundStyle(Color.red)
                    .accessibilityLabel("Export error: \(exportError)")
            }

            // Cancel
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityLabel("Cancel export")
            }
        }
        .padding(DictlySpacing.md)
        .frame(minWidth: 360, minHeight: 200)
        .background(DictlyColors.background)
        .onAppear {
            AccessibilityNotification.LayoutChanged().post()
        }
        .accessibilityLabel("Export as Markdown sheet")
    }

    // MARK: - Export Actions

    private func exportSession() {
        let markdown = MarkdownExporter.exportSession(session)
        let filename = MarkdownExporter.suggestedFilename(for: session)
        saveMarkdown(markdown, suggestedFilename: filename)
    }

    private func exportCampaign(_ campaign: Campaign) {
        let markdown = MarkdownExporter.exportCampaign(campaign)
        let filename = MarkdownExporter.suggestedFilename(for: campaign)
        saveMarkdown(markdown, suggestedFilename: filename)
    }

    // MARK: - Save Panel + Post-Export

    private func saveMarkdown(_ markdown: String, suggestedFilename: String) {
        Task { @MainActor in
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = suggestedFilename
            panel.allowsOtherFileTypes = false

            guard let keyWindow = NSApp.keyWindow else {
                exportError = "Unable to present save dialog. Please try again."
                return
            }

            let response = await panel.beginSheetModal(for: keyWindow)
            guard response == .OK, let url = panel.url else { return }

            let finalURL = url.pathExtension.lowercased() == "md"
                ? url
                : url.appendingPathExtension("md")

            do {
                try markdown.write(to: finalURL, atomically: true, encoding: .utf8)
                logger.info("Exported markdown to \(finalURL.lastPathComponent)")
                isPresented = false
                postExportFeedback(url: finalURL)
            } catch {
                logger.error("Export failed: \(error.localizedDescription)")
                exportError = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Post-Export Feedback (AC #4)

    private func postExportFeedback(url: URL) {
        // Reveal in Finder (primary feedback)
        NSWorkspace.shared.activateFileViewerSelecting([url])

        // Local notification (supplementary feedback)
        Task {
            let center = UNUserNotificationCenter.current()
            // Request authorization; if already granted, this is a no-op returning (true, nil)
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Export Complete"
            content.body = "Saved \(url.lastPathComponent)"
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
