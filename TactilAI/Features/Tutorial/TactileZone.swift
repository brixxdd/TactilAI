import SwiftUI

struct TactileZone: View {
    let index: Int
    let width: CGFloat
    let height: CGFloat
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    @State private var glowPhase: Bool = false

    var body: some View {
        Button {
            onTap?()
        } label: {
            ZStack {
                zoneGlow
                zoneGlass
                zoneGradientBorder
                zoneContent
            }
            .frame(width: width, height: height)
            .scaleEffect(isSelected ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TactileZoneData.zones[index].label)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
    }

    private var zone: (symbol: String, label: String, word: String, color1: String, color2: String) {
        TactileZoneData.zones[index]
    }

    private var color1: Color { Color(hex: zone.color1) }
    private var color2: Color { Color(hex: zone.color2) }

    private var zoneGlow: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(
                RadialGradient(
                    colors: [color1.opacity(isSelected ? 0.35 : 0.12), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: height * 0.6
                )
            )
    }

    private var zoneGlass: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .fill(color1.opacity(0.08))
            )
    }

    private var zoneGradientBorder: some View {
        RoundedRectangle(cornerRadius: 28)
            .stroke(
                LinearGradient(
                    colors: [
                        color1.opacity(isSelected ? 0.8 : 0.35),
                        color2.opacity(isSelected ? 0.6 : 0.15),
                        color1.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 2 : 1
            )
    }

    private var zoneContent: some View {
        VStack(spacing: 14) {
            ZStack {
                Image(systemName: zone.symbol)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(color1.opacity(0.4))
                    .blur(radius: 12)
                    .scaleEffect(glowPhase ? 1.1 : 0.95)

                Image(systemName: zone.symbol)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color1, color2],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text(zone.label)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: color1.opacity(0.3), radius: 8)
        }
    }
}

struct TactileZoneData {
    static let zones: [(symbol: String, label: String, word: String, color1: String, color2: String)] = [
        ("checkmark.circle.fill",          "Sí",           "Sí",       "34C759", "4ECDC4"),
        ("xmark.circle.fill",              "No",           "No",       "FF453A", "FF6B6B"),
        ("questionmark.circle.fill",       "Necesito algo","Ayuda",    "FF9500", "FFB84D"),
        ("exclamationmark.triangle.fill", "Emergencia",   "Emergencia", "FF453A", "FF2D55")
    ]
}

#Preview {
    ZStack {
        Color(hex: "07071A").ignoresSafeArea()
        HStack(spacing: 12) {
            TactileZone(index: 0, width: 160, height: 160)
            TactileZone(index: 1, width: 160, height: 160)
        }
    }
}
