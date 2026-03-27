// JuliaView.swift
// TactilAI
//
// Vista de la persona sordociega. Diseño Liquid Glass.
// 4 zonas táctiles con efectos de luz, glow y animaciones.

import SwiftUI

struct JuliaView: View {

    @State private var lastTapped: String = ""
    @State private var showOverlay: Bool = false
    @State private var pulseAmount: CGFloat = 1.0
    @State private var glowPhase: Bool = false

    private let zones: [(symbol: String, label: String, word: String, color1: String, color2: String)] = [
        ("checkmark.circle.fill", "Sí / Bien", "Sí", "34C759", "4ECDC4"),
        ("xmark.circle.fill", "No / Mal", "No", "FF453A", "FF6B6B"),
        ("questionmark.circle.fill", "Necesito algo", "Ayuda", "FF9500", "FFB84D"),
        ("exclamationmark.triangle.fill", "Emergencia", "Emergencia", "FF453A", "FF2D55")
    ]

    var body: some View {
        ZStack {
            // Fondo base
            Color(hex: "07071A")
                .ignoresSafeArea()

            // AMBIENT ORBS
            Circle()
                .fill(Color(hex: "7B6EF6").opacity(0.15))
                .frame(width: 350, height: 350)
                .blur(radius: 90)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color(hex: "4ECDC4").opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 140, y: 300)

            Circle()
                .fill(Color(hex: "FF9500").opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -60, y: 400)

            VStack(spacing: 0) {
                // HEADER
                headerSection
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // 4 ZONAS TÁCTILES
                GeometryReader { geo in
                    let halfW = (geo.size.width - 52) / 2
                    let halfH = (geo.size.height - 28) / 2

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            zoneCard(index: 0, width: halfW, height: halfH)
                            zoneCard(index: 1, width: halfW, height: halfH)
                        }
                        HStack(spacing: 12) {
                            zoneCard(index: 2, width: halfW, height: halfH)
                            zoneCard(index: 3, width: halfW, height: halfH)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)
            }

            // Overlay de confirmación
            if showOverlay {
                overlayFlash
            }
        }
        .fontDesign(.rounded)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
            Task {
                try? await HapticEngine.shared.prepare()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            // Avatar pulsante
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "7B6EF6").opacity(0.4), Color(hex: "7B6EF6").opacity(0.0)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 35
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(glowPhase ? 1.15 : 1.0)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "7B6EF6"), Color(hex: "4ECDC4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Text("J")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Modo Julia")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hex: "4ECDC4"))
                        .frame(width: 7, height: 7)
                        .scaleEffect(glowPhase ? 1.3 : 0.8)

                    Text("Toca para responder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Zone Card

    private func zoneCard(index: Int, width: CGFloat, height: CGFloat) -> some View {
        let zone = zones[index]
        let color1 = Color(hex: zone.color1)
        let color2 = Color(hex: zone.color2)
        let isActive = lastTapped == zone.label && showOverlay

        return Button {
            zoneTapped(label: zone.label, word: zone.word)
        } label: {
            ZStack {
                // Glow de fondo
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        RadialGradient(
                            colors: [color1.opacity(isActive ? 0.35 : 0.12), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: height * 0.6
                        )
                    )

                // Glass card
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 28)
                    .fill(color1.opacity(0.08))

                // Gradient border
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color1.opacity(isActive ? 0.8 : 0.35),
                                color2.opacity(isActive ? 0.6 : 0.15),
                                color1.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isActive ? 2 : 1
                    )

                // Contenido
                VStack(spacing: 14) {
                    // Icono con glow
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
            .frame(width: width, height: height)
            .scaleEffect(isActive ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(zone.label)
    }

    // MARK: - Overlay flash

    private var overlayFlash: some View {
        let color = overlayColor(for: lastTapped)
        return ZStack {
            color.opacity(0.25)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Ring pulse
            Circle()
                .stroke(color.opacity(0.5), lineWidth: 3)
                .frame(width: 120, height: 120)
                .scaleEffect(pulseAmount)
                .opacity(2.0 - Double(pulseAmount))

            Image(systemName: overlayIcon(for: lastTapped))
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: 20)
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    // MARK: - Acción al tocar

    private func zoneTapped(label: String, word: String) {
        lastTapped = label
        HapticEngine.shared.play(word: word)

        pulseAmount = 1.0
        withAnimation(.easeIn(duration: 0.15)) {
            showOverlay = true
        }
        withAnimation(.easeOut(duration: 0.8)) {
            pulseAmount = 2.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.25)) {
                showOverlay = false
            }
        }
    }

    // MARK: - Helpers

    private func overlayColor(for label: String) -> Color {
        switch label {
        case "Sí / Bien": return Color(hex: "34C759")
        case "No / Mal": return Color(hex: "FF453A")
        case "Necesito algo": return Color(hex: "FF9500")
        case "Emergencia": return Color(hex: "FF453A")
        default: return .clear
        }
    }

    private func overlayIcon(for label: String) -> String {
        switch label {
        case "Sí / Bien": return "checkmark.circle.fill"
        case "No / Mal": return "xmark.circle.fill"
        case "Necesito algo": return "questionmark.circle.fill"
        case "Emergencia": return "exclamationmark.triangle.fill"
        default: return "circle"
        }
    }
}

#Preview {
    JuliaView()
}
