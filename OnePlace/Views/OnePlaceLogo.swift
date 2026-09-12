import SwiftUI

struct OnePlaceLogo: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.071, green: 0.243, blue: 0.278), Color(red: 0.031, green: 0.49, blue: 0.514)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.1875)
                .stroke(Color(red: 0.949, green: 0.98, blue: 0.969), lineWidth: size * 0.0742)
                .frame(width: size * 0.5586, height: size * 0.5586)
            Path { path in
                path.move(to: CGPoint(x: size * 0.4375, y: size * 0.415))
                path.addLine(to: CGPoint(x: size * 0.5098, y: size * 0.3604))
                path.addLine(to: CGPoint(x: size * 0.5098, y: size * 0.6338))
            }
            .stroke(Color(red: 0.949, green: 0.98, blue: 0.969), style: StrokeStyle(lineWidth: size * 0.0742, lineCap: .round, lineJoin: .round))
            Circle()
                .fill(Color(red: 0.071, green: 0.243, blue: 0.278))
                .frame(width: size * 0.1836, height: size * 0.1836)
                .overlay(Circle().fill(Color(red: 0.788, green: 0.945, blue: 0.49)).padding(size * 0.03125))
                .offset(x: size * 0.2441, y: -size * 0.248)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("OnePlace")
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

                Text("A little more life. A little less admin.")
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
