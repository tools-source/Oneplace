import SwiftUI

struct OnePlaceLogo: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(DesignSystem.logoGradient)
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.05, green: 0.58, blue: 0.68).opacity(0.40), radius: size * 0.22, x: 0, y: size * 0.10)

            // Subtle inner ring
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: max(1, size * 0.018))
                .frame(width: size * 0.76, height: size * 0.76)

            // Numeral
            Text("1")
                .font(.system(size: size * 0.50, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: -size * 0.03)

            // "P" label below numeral
            Text("PLACE")
                .font(.system(size: size * 0.13, weight: .bold, design: .rounded))
                .tracking(size * 0.02)
                .foregroundStyle(.white.opacity(0.72))
                .offset(y: size * 0.28)

            // Constellation dots
            Group {
                Circle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: size * 0.055, height: size * 0.055)
                    .offset(x: size * 0.28, y: -size * 0.30)

                Circle()
                    .fill(Color.white.opacity(0.40))
                    .frame(width: size * 0.038, height: size * 0.038)
                    .offset(x: size * 0.36, y: -size * 0.18)

                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: size * 0.028, height: size * 0.028)
                    .offset(x: size * 0.22, y: -size * 0.38)
            }
        }
    }
}

struct OnePlaceWordmark: View {
    var body: some View {
        HStack(spacing: 10) {
            OnePlaceLogo(size: 44)

            VStack(alignment: .leading, spacing: 1) {
                Text("One")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(DesignSystem.accentColor)
                + Text("Place")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Everything in one home")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 32) {
        OnePlaceLogo(size: 96)
        OnePlaceLogo(size: 60)
        OnePlaceLogo(size: 36)
        OnePlaceWordmark()
    }
    .padding(32)
    .background(Color(uiColor: .systemBackground))
}
