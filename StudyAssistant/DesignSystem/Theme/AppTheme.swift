import SwiftUI

enum AppTheme {

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat   = 8
        static let md: CGFloat   = 12
        static let lg: CGFloat   = 16
        static let card: CGFloat = 20
        static let xl: CGFloat   = 28
    }

    // MARK: - Semantic Colors

    enum Color {
        static let accent     = SwiftUI.Color.accentColor
        static let primary    = SwiftUI.Color.primary
        static let secondary  = SwiftUI.Color.secondary
        static let background = SwiftUI.Color(.systemBackground)

        // Category tints
        static let session   = SwiftUI.Color.orange
        static let document  = SwiftUI.Color.blue
        static let chat      = SwiftUI.Color.purple
        static let analytics = SwiftUI.Color.green
    }

    // MARK: - Shadows

    enum Shadows {
        static let card = AppShadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
        static let soft = AppShadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Shadow helper

struct AppShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func appShadow(_ shadow: AppShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
