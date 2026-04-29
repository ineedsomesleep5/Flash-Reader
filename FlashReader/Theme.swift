import SwiftUI

enum FRTheme {
    static let background = Color(red: 0.045, green: 0.043, blue: 0.039)
    static let readerBackground = Color(red: 0.018, green: 0.018, blue: 0.017)
    static let surface = Color(red: 0.086, green: 0.082, blue: 0.075)
    static let elevated = Color(red: 0.125, green: 0.117, blue: 0.105)
    static let primaryText = Color(red: 0.95, green: 0.925, blue: 0.875)
    static let secondaryText = Color(red: 0.55, green: 0.515, blue: 0.47)
    static let accent = Color(red: 0.886, green: 0.29, blue: 0.29)
    static let gold = Color(red: 0.94, green: 0.68, blue: 0.32)
    static let mint = Color(red: 0.39, green: 0.78, blue: 0.62)

    static let pageGradient = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.095, blue: 0.075),
            background,
            Color(red: 0.035, green: 0.035, blue: 0.034)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(FRTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func frCard() -> some View {
        modifier(CardStyle())
    }

    func pageBackground() -> some View {
        background(FRTheme.pageGradient.ignoresSafeArea())
    }
}
