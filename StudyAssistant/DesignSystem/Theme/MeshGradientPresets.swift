import SwiftUI

// MARK: - Adaptive Background View
//
// Drop-in replacement for the raw MeshGradient calls in each feature view.
// Automatically switches between the light and dark preset based on colorScheme.

struct AdaptiveBackground: View {
    enum Style { case study, session, document, chat }

    let style: Style
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch style {
            case .study:    colorScheme == .dark ? MeshGradient.studyDark()    : MeshGradient.studyLight()
            case .session:  colorScheme == .dark ? MeshGradient.sessionDark()  : MeshGradient.sessionLight()
            case .document: colorScheme == .dark ? MeshGradient.documentDark() : MeshGradient.documentLight()
            case .chat:     colorScheme == .dark ? MeshGradient.chatDark()     : MeshGradient.chatLight()
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: colorScheme)
    }
}

// MARK: - Dark presets  (near-black, barely-perceptible hue per tab)

extension MeshGradient {

    static func studyDark() -> MeshGradient {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.4, 0.6), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.062, green: 0.064, blue: 0.090),
                Color(red: 0.055, green: 0.058, blue: 0.082),
                Color(red: 0.060, green: 0.062, blue: 0.086),
                Color(red: 0.052, green: 0.055, blue: 0.078),
                Color(red: 0.045, green: 0.048, blue: 0.070),
                Color(red: 0.055, green: 0.057, blue: 0.080),
                Color(red: 0.068, green: 0.070, blue: 0.095),
                Color(red: 0.058, green: 0.062, blue: 0.086),
                Color(red: 0.062, green: 0.064, blue: 0.090)
            ]
        )
    }

    static func sessionDark() -> MeshGradient {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.6, 0.4), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.088, green: 0.075, blue: 0.062),
                Color(red: 0.080, green: 0.068, blue: 0.056),
                Color(red: 0.085, green: 0.072, blue: 0.060),
                Color(red: 0.075, green: 0.064, blue: 0.052),
                Color(red: 0.068, green: 0.058, blue: 0.046),
                Color(red: 0.078, green: 0.066, blue: 0.054),
                Color(red: 0.092, green: 0.078, blue: 0.064),
                Color(red: 0.082, green: 0.070, blue: 0.058),
                Color(red: 0.086, green: 0.074, blue: 0.060)
            ]
        )
    }

    static func documentDark() -> MeshGradient {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.5, 0.5), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.052, green: 0.062, blue: 0.082),
                Color(red: 0.046, green: 0.056, blue: 0.075),
                Color(red: 0.050, green: 0.060, blue: 0.080),
                Color(red: 0.044, green: 0.054, blue: 0.072),
                Color(red: 0.038, green: 0.048, blue: 0.065),
                Color(red: 0.048, green: 0.058, blue: 0.076),
                Color(red: 0.056, green: 0.066, blue: 0.086),
                Color(red: 0.050, green: 0.060, blue: 0.080),
                Color(red: 0.054, green: 0.064, blue: 0.084)
            ]
        )
    }

    static func chatDark() -> MeshGradient {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.4, 0.4), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.072, green: 0.058, blue: 0.092),
                Color(red: 0.065, green: 0.052, blue: 0.084),
                Color(red: 0.070, green: 0.056, blue: 0.088),
                Color(red: 0.060, green: 0.048, blue: 0.078),
                Color(red: 0.052, green: 0.042, blue: 0.068),
                Color(red: 0.064, green: 0.052, blue: 0.082),
                Color(red: 0.076, green: 0.062, blue: 0.096),
                Color(red: 0.068, green: 0.055, blue: 0.088),
                Color(red: 0.072, green: 0.058, blue: 0.092)
            ]
        )
    }
}

// MARK: - Light presets  (near-white, barely-perceptible hue per tab)

extension MeshGradient {

    static func studyLight() -> MeshGradient {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.4, 0.6), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.952, green: 0.954, blue: 0.972),
                Color(red: 0.960, green: 0.962, blue: 0.978),
                Color(red: 0.955, green: 0.957, blue: 0.974),
                Color(red: 0.958, green: 0.960, blue: 0.976),
                Color(red: 0.964, green: 0.966, blue: 0.982),
                Color(red: 0.957, green: 0.959, blue: 0.975),
                Color(red: 0.950, green: 0.952, blue: 0.970),
                Color(red: 0.956, green: 0.958, blue: 0.974),
                Color(red: 0.952, green: 0.954, blue: 0.972)
            ]
        )
    }

    static func sessionLight() -> MeshGradient {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.6, 0.4), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.976, green: 0.968, blue: 0.958),
                Color(red: 0.980, green: 0.972, blue: 0.963),
                Color(red: 0.977, green: 0.969, blue: 0.960),
                Color(red: 0.979, green: 0.971, blue: 0.961),
                Color(red: 0.983, green: 0.975, blue: 0.966),
                Color(red: 0.978, green: 0.970, blue: 0.961),
                Color(red: 0.974, green: 0.966, blue: 0.956),
                Color(red: 0.977, green: 0.969, blue: 0.959),
                Color(red: 0.976, green: 0.968, blue: 0.958)
            ]
        )
    }

    static func documentLight() -> MeshGradient {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.5, 0.5), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.946, green: 0.956, blue: 0.972),
                Color(red: 0.952, green: 0.961, blue: 0.976),
                Color(red: 0.948, green: 0.958, blue: 0.974),
                Color(red: 0.951, green: 0.960, blue: 0.975),
                Color(red: 0.957, green: 0.965, blue: 0.979),
                Color(red: 0.950, green: 0.959, blue: 0.974),
                Color(red: 0.944, green: 0.954, blue: 0.970),
                Color(red: 0.949, green: 0.958, blue: 0.973),
                Color(red: 0.946, green: 0.956, blue: 0.972)
            ]
        )
    }

    static func chatLight() -> MeshGradient {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.4, 0.4), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                Color(red: 0.960, green: 0.954, blue: 0.976),
                Color(red: 0.965, green: 0.959, blue: 0.980),
                Color(red: 0.961, green: 0.955, blue: 0.977),
                Color(red: 0.964, green: 0.958, blue: 0.979),
                Color(red: 0.969, green: 0.963, blue: 0.983),
                Color(red: 0.963, green: 0.957, blue: 0.978),
                Color(red: 0.958, green: 0.952, blue: 0.974),
                Color(red: 0.962, green: 0.956, blue: 0.977),
                Color(red: 0.960, green: 0.954, blue: 0.976)
            ]
        )
    }
}
