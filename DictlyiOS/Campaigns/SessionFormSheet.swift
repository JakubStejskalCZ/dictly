import SwiftUI
import DictlyModels
import DictlyTheme

struct SessionFormSheet: View {
    let session: Session

    @Environment(\.dismiss) private var dismiss

    @State private var title: String

    init(session: Session) {
        self.session = session
        _title = State(initialValue: session.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session Title", text: $title)
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        session.title = trimmed
        dismiss()
    }
}
