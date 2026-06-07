import SwiftUI
import UIKit

enum DesignSystem {

    // MARK: - Colors

    static let primaryBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.04, green: 0.07, blue: 0.10, alpha: 1)
                : UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1)
        }
    )
    static let secondaryBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.11, blue: 0.15, alpha: 1)
                : UIColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1)
        }
    )
    static let accentColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.20, green: 0.82, blue: 0.90, alpha: 1)
                : UIColor(red: 0.05, green: 0.58, blue: 0.69, alpha: 1)
        }
    )
    static let accentSoft = accentColor.opacity(0.14)

    static let secondaryAccent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.60, green: 0.56, blue: 1.00, alpha: 1)
                : UIColor(red: 0.36, green: 0.28, blue: 0.85, alpha: 1)
        }
    )

    static let warmAccent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.76, blue: 0.36, alpha: 1)
                : UIColor(red: 0.82, green: 0.48, blue: 0.06, alpha: 1)
        }
    )
    static let cardBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.11, blue: 0.14, alpha: 1)
                : UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1)
        }
    )
    static let elevatedCardBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.17, blue: 0.22, alpha: 1)
                : UIColor(red: 0.99, green: 1.00, blue: 1.00, alpha: 1)
        }
    )

    static let primaryTextColor = Color.primary
    static let secondaryTextColor = Color.secondary

    static let gainColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.24, green: 0.90, blue: 0.58, alpha: 1)
                : UIColor(red: 0.07, green: 0.57, blue: 0.30, alpha: 1)
        }
    )
    static let oweColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.48, blue: 0.44, alpha: 1)
                : UIColor(red: 0.85, green: 0.18, blue: 0.15, alpha: 1)
        }
    )

    static let borderColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.09)
                : UIColor.black.withAlphaComponent(0.07)
        }
    )
    static let cardBorderColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.11)
                : UIColor(red: 0.05, green: 0.58, blue: 0.69, alpha: 0.12)
        }
    )
    static let tabBarBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.09, blue: 0.13, alpha: 0.96)
                : UIColor(red: 0.99, green: 1.00, blue: 1.00, alpha: 0.96)
        }
    )
    static let shadowColor = Color.black.opacity(0.10)
    static let glassStroke = LinearGradient(
        colors: [
            Color.white.opacity(0.28),
            Color.white.opacity(0.06),
            accentColor.opacity(0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Gradients

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.04, green: 0.07, blue: 0.10, alpha: 1)
                        : UIColor(red: 0.96, green: 0.98, blue: 1.00, alpha: 1)
                }
            ),
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.06, green: 0.10, blue: 0.14, alpha: 1)
                        : UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1)
                }
            ),
            secondaryBackground
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [
            elevatedCardBackground,
            cardBackground.opacity(0.97)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let highlightedCardGradient = LinearGradient(
        colors: [
            accentColor.opacity(0.18),
            secondaryAccent.opacity(0.08),
            elevatedCardBackground
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Brand tile gradient — mirrors the app icon (teal → blue → indigo)
    static let logoGradient = LinearGradient(
        colors: [
            Color(red: 0.098, green: 0.725, blue: 0.839),
            Color(red: 0.173, green: 0.455, blue: 0.839),
            Color(red: 0.290, green: 0.200, blue: 0.784)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroBannerGradient = LinearGradient(
        colors: [
            accentColor.opacity(0.22),
            secondaryAccent.opacity(0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Spacing

    static let smallSpacing: CGFloat = 6
    static let mediumSpacing: CGFloat = 10
    static let largeSpacing: CGFloat = 16

    static let cardPadding: CGFloat = 16
    static let rowHeight: CGFloat = 54
    static let cardShadowRadius: CGFloat = 14
    static let badgeSize: CGFloat = 32
    static let tabBarContentInset: CGFloat = 132

    // MARK: - Corner Radius

    static let cardCornerRadius: CGFloat = 16
    static let largeCardCornerRadius: CGFloat = 18

    // MARK: - Motion

    /// Standard spring used for interactive state changes across the app.
    static let interactiveSpring = Animation.spring(response: 0.35, dampingFraction: 0.78)
}

// MARK: - Reusable Button Styles

/// Gives any button a subtle, premium press response (scale + dim) with light haptics.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// `.buttonStyle(.pressable)` — subtle scale + haptic on press.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
