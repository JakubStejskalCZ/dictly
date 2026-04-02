import SwiftUI
import UIKit

/// `UIViewControllerRepresentable` wrapper for `UIActivityViewController`.
///
/// Presents the standard iOS share sheet with the given activity items.
/// The completion handler is called on the main actor after the sheet is dismissed.
///
/// Usage:
/// ```swift
/// ActivityViewControllerRepresentable(
///     activityItems: [bundleURL],
///     completion: { completed, error in ... }
/// )
/// ```
struct ActivityViewControllerRepresentable: UIViewControllerRepresentable {

    let activityItems: [Any]
    let completion: @MainActor (Bool, Error?) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, error in
            Task { @MainActor in
                completion(completed, error)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
