import SwiftUI

/// Animated equaliser-style waveform that reacts to a normalised audio level (0–1).
/// Uses a bell-curve envelope so centre bars are tallest, tapering at the edges.
struct WaveformView: View {
    var level: Float          // 0.0 – 1.0
    var color: Color = .accentColor
    var barCount: Int = 32
    var maxHeight: CGFloat = 60
    var minHeight: CGFloat = 4
    var spacing: CGFloat = 3
    var barWidth: CGFloat = 3

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { i in
                let t = Float(i) / Float(barCount - 1)          // 0…1 across all bars
                let center: Float = 0.5
                let sigma: Float = 0.28
                let envelope = exp(-pow(t - center, 2) / (2 * sigma * sigma))
                let h = max(minHeight, CGFloat(level * Float(maxHeight) * envelope))

                Capsule()
                    .fill(color)
                    .frame(width: barWidth, height: h)
            }
        }
        .animation(.spring(response: 0.14, dampingFraction: 0.65), value: level)
    }
}

// MARK: - Idle pulse variant (plays when not recording)

struct IdleWaveformView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate * .pi
            WaveformView(
                level: Float(0.18 + 0.10 * sin(phase)),
                color: .primary.opacity(0.35),
                maxHeight: 36
            )
        }
    }
}

#Preview {
    ZStack {
        MeshGradient.sessionDark().ignoresSafeArea()
        VStack(spacing: 32) {
            WaveformView(level: 0.8, color: .orange)
            WaveformView(level: 0.3, color: .orange)
            IdleWaveformView()
        }
    }
}
