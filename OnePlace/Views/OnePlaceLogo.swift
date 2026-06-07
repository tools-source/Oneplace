import SwiftUI

struct OnePlaceLogo: View {
    var size: CGFloat = 72

    private var cornerRadius: CGFloat { size * 0.2237 } // iOS squircle ratio

    var body: some View {
        ZStack {
            // Base brand tile
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DesignSystem.logoGradient)

            // Top sheen for depth
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.30), Color.white.opacity(0)],
                        center: UnitPoint(x: 0.5, y: 0.06),
                        startRadius: 0,
                        endRadius: size * 0.9
                    )
                )

            // Orbit ring
            Ellipse()
                .stroke(Color.white.opacity(0.24), lineWidth: max(1, size * 0.016))
                .frame(width: size * 0.66, height: size * 0.34)
                .rotationEffect(.degrees(-22))

            // Satellite dot with glow
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.06, height: size * 0.06)
                .shadow(color: Color.white.opacity(0.85), radius: size * 0.045)
                .offset(x: size * 0.18, y: -size * 0.20)

            // Numeral
            Text("1")
                .font(.system(size: size * 0.56, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0.02, green: 0.13, blue: 0.22).opacity(0.28),
                        radius: size * 0.03, x: 0, y: size * 0.02)

            // Hairline edge highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: max(0.5, size * 0.008))
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.07, green: 0.42, blue: 0.74).opacity(0.38),
                radius: size * 0.18, x: 0, y: size * 0.09)
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
