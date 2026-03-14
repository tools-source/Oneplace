import SwiftUI
import UIKit

enum DesignSystem {

    // MARK: - Colors

    static let primaryBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.05, green: 0.08, blue: 0.09, alpha: 1)
                : UIColor(red: 0.97, green: 0.98, blue: 0.97, alpha: 1)
        }
    )
    static let secondaryBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.12, blue: 0.14, alpha: 1)
                : UIColor(red: 0.94, green: 0.96, blue: 0.95, alpha: 1)
        }
    )
    static let accentColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.35, green: 0.80, blue: 0.88, alpha: 1)
                : UIColor(red: 0.03, green: 0.45, blue: 0.55, alpha: 1)
        }
    )
    static let accentSoft = accentColor.opacity(0.16)
    static let warmAccent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.96, green: 0.73, blue: 0.37, alpha: 1)
                : UIColor(red: 0.78, green: 0.45, blue: 0.08, alpha: 1)
        }
    )
    static let cardBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.09, green: 0.15, blue: 0.18, alpha: 1)
                : UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
    )
    static let elevatedCardBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.18, blue: 0.21, alpha: 1)
                : UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1)
        }
    )

    static let primaryTextColor = Color.primary
    static let secondaryTextColor = Color.secondary
    static let gainColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.31, green: 0.88, blue: 0.59, alpha: 1)
                : UIColor(red: 0.10, green: 0.55, blue: 0.28, alpha: 1)
        }
    )
    static let oweColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.98, green: 0.53, blue: 0.48, alpha: 1)
                : UIColor(red: 0.82, green: 0.22, blue: 0.19, alpha: 1)
        }
    )

    static let borderColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.10)
                : UIColor.black.withAlphaComponent(0.08)
        }
    )
    static let cardBorderColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor(red: 0.03, green: 0.45, blue: 0.55, alpha: 0.10)
        }
    )
    static let tabBarBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.11, blue: 0.13, alpha: 0.94)
                : UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 0.94)
        }
    )
    static let shadowColor = Color.black.opacity(0.08)

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.04, green: 0.07, blue: 0.08, alpha: 1)
                        : UIColor(red: 0.96, green: 0.98, blue: 0.97, alpha: 1)
                }
            ),
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.07, green: 0.11, blue: 0.13, alpha: 1)
                        : UIColor(red: 0.95, green: 0.96, blue: 0.94, alpha: 1)
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
            cardBackground.opacity(0.98)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let highlightedCardGradient = LinearGradient(
        colors: [
            accentColor.opacity(0.22),
            warmAccent.opacity(0.12),
            elevatedCardBackground
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Spacing

    static let smallSpacing: CGFloat = 6
    static let mediumSpacing: CGFloat = 10
    static let largeSpacing: CGFloat = 16

    static let cardPadding: CGFloat = 14
    static let rowHeight: CGFloat = 52
    static let cardShadowRadius: CGFloat = 12
    static let badgeSize: CGFloat = 30
    static let tabBarContentInset: CGFloat = 132

    // MARK: - Corner Radius

    static let cardCornerRadius: CGFloat = 16
    static let largeCardCornerRadius: CGFloat = 24
}
