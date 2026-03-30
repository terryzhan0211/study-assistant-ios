import SwiftUI

// MARK: - Style

struct GlassButtonStyle: ButtonStyle {
    var tint: Color
    var isProminent: Bool

    init(tint: Color = .accentColor, isProminent: Bool = false) {
        self.tint = tint
        self.isProminent = isProminent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm + 2)
            .foregroundStyle(isProminent ? .white : tint)
            .background {
                if isProminent {
                    Capsule(style: .continuous)
                        .fill(tint.gradient)
                } else {
                    Capsule(style: .continuous)
                        .glassEffect(in: Capsule(style: .continuous))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Convenience extensions

extension Button {
    /// Applies the glass capsule button style.
    @MainActor
    func glassButton(tint: Color = .accentColor) -> some View {
        self.buttonStyle(GlassButtonStyle(tint: tint))
    }

    /// Applies a prominent (filled) capsule button style.
    @MainActor
    func prominentButton(tint: Color = .accentColor) -> some View {
        self.buttonStyle(GlassButtonStyle(tint: tint, isProminent: true))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        MeshGradient.studyDark()
            .ignoresSafeArea()

        VStack(spacing: AppTheme.Spacing.md) {
            Button {
            } label: {
                Label("Start Session", systemImage: "mic.fill")
                    .font(.headline)
            }
            .prominentButton(tint: .orange)

            Button {
            } label: {
                Label("Import PDF", systemImage: "doc.badge.plus")
                    .font(.headline)
            }
            .glassButton(tint: .blue)
        }
    }
}
