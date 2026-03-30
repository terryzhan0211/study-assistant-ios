import SwiftUI

/// A container that applies the iOS 26 Liquid Glass material with a rounded rectangle shape.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: CGFloat
    private let content: Content

    init(
        cornerRadius: CGFloat = AppTheme.Radius.card,
        padding: CGFloat = AppTheme.Spacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Convenience modifier

extension View {
    /// Wraps the view in an iOS 26 glass card background.
    func glassCard(cornerRadius: CGFloat = AppTheme.Radius.card) -> some View {
        self.padding(AppTheme.Spacing.md)
            .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        MeshGradient.studyDark()
            .ignoresSafeArea()

        VStack(spacing: AppTheme.Spacing.md) {
            GlassCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Today's Sessions")
                        .font(.headline)
                    Text("3 lectures recorded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard(cornerRadius: AppTheme.Radius.xl) {
                Label("Start Recording", systemImage: "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(AppTheme.Spacing.md)
    }
}
