import SwiftUI
import SwiftData
import DictlyModels
import DictlyTheme

/// Sheet view for editing a session-level summary note.
///
/// Presented from the "Session Notes" toolbar button in `SessionReviewScreen`.
/// Auto-saves on dismiss — no explicit save button required.
struct SessionNotesView: View {
    @Bindable var session: Session
    @Environment(\.dismiss) private var dismiss

    @State private var editingNote: String = ""
    private var originalNote: String

    init(session: Session) {
        self.session = session
        self.originalNote = session.summaryNote ?? ""
        self._editingNote = State(initialValue: session.summaryNote ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DictlySpacing.md) {
            // Header
            VStack(alignment: .leading, spacing: DictlySpacing.xs) {
                Text("Session Notes")
                    .font(DictlyTypography.h3)
                    .foregroundStyle(DictlyColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("\(session.title) · \(formatSessionDate(session.date))")
                    .font(DictlyTypography.caption)
                    .foregroundStyle(DictlyColors.textSecondary)
            }

            // TextEditor with placeholder overlay
            ZStack(alignment: .topLeading) {
                TextEditor(text: $editingNote)
                    .font(DictlyTypography.body)
                    .scrollContentBackground(.hidden)
                    .background(DictlyColors.surface)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Session summary note")

                if editingNote.isEmpty {
                    Text("Write a session summary…")
                        .font(DictlyTypography.body)
                        .foregroundStyle(DictlyColors.textSecondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .background(DictlyColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Done button
            HStack {
                Spacer()
                Button("Done") {
                    saveAndDismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityLabel("Save and close session notes")
            }
        }
        .padding(DictlySpacing.md)
        .frame(minWidth: 400, minHeight: 250)
        .background(DictlyColors.background)
        .onDisappear {
            saveNote()
        }
        .accessibilityLabel("Session notes editor")
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        saveNote()
        dismiss()
    }

    private func saveNote() {
        let trimmed = editingNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: String? = trimmed.isEmpty ? nil : editingNote
        session.summaryNote = newValue
        if editingNote != originalNote {
            AccessibilityNotification.Announcement("Session notes saved").post()
        }
    }
}

// MARK: - Date Formatting

private func formatSessionDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}
