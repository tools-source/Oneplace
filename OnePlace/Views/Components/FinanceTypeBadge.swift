import SwiftUI

struct FinanceTypeBadge: View {
    enum Kind {
        case gain
        case owe
        case net(isPositive: Bool)
    }

    let kind: Kind
    var size: CGFloat = DesignSystem.badgeSize

    init(type: FinanceType, size: CGFloat = DesignSystem.badgeSize) {
        self.kind = type == .gain ? .gain : .owe
        self.size = size
    }

    init(netTotal: Double, size: CGFloat = DesignSystem.badgeSize) {
        self.kind = .net(isPositive: netTotal >= 0)
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: size, height: size)

            Image(systemName: symbol)
                .font(.system(size: size * 0.48, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }

    private var symbol: String {
        switch kind {
        case .gain:
            return "arrow.down"
        case .owe:
            return "arrow.up"
        case let .net(isPositive):
            return isPositive ? "arrow.up.right" : "arrow.down.right"
        }
    }

    private var tint: Color {
        switch kind {
        case .gain:
            return .green
        case .owe:
            return .red
        case let .net(isPositive):
            return isPositive ? .blue : .red
        }
    }
}
