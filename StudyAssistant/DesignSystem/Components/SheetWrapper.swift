import SwiftUI

/// Wraps any view in a sheet with a "Done" dismiss button in the toolbar.
/// Used by Home quick-action buttons so the user can return to Home easily.
struct SheetWrapper<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
    }
}
