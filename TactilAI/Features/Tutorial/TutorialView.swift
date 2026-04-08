import SwiftUI

struct TutorialStep {
    let word: String
    let description: String
    let hapticKey: String
    let expectedZone: Int
}

struct TutorialView: View {
    let onComplete: () -> Void

    @State private var currentStepIndex: Int = 0
    @State private var showingZones: Bool = false
    @State private var selectedZone: Int? = nil
    @State private var feedbackShown: Bool = false

    @AppStorage("tutorialCompleted") private var tutorialCompleted = false

    private let steps: [TutorialStep] = [
        TutorialStep(word: "Sí", description: "Esto significa SÍ", hapticKey: "Sí", expectedZone: 0),
        TutorialStep(word: "No", description: "Esto significa NO", hapticKey: "No", expectedZone: 1),
        TutorialStep(word: "Necesito algo", description: "Esto significa NECESITO ALGO", hapticKey: "Ayuda", expectedZone: 2),
        TutorialStep(word: "Bien", description: "Esto significa BIEN", hapticKey: "Bien", expectedZone: 3)
    ]

    var body: some View {
        ZStack {
            Color(hex: "07071A")
                .ignoresSafeArea()

            ambientOrbs

            VStack(spacing: 24) {
                progressSection
                    .padding(.top, 20)

                Spacer()

                instructionSection

                actionButtons

                zonesSection

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .fontDesign(.rounded)
        .onAppear {
            Task {
                try? await HapticEngine.shared.prepare()
            }
        }
    }

    // MARK: - Ambient Orbs

    private var ambientOrbs: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "7B6EF6").opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -80, y: -250)

            Circle()
                .fill(Color(hex: "4ECDC4").opacity(0.08))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 120, y: 350)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 12) {
            Text("Paso \(currentStepIndex + 1) de \(steps.count)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "7B6EF6"), Color(hex: "4ECDC4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (Double(currentStepIndex) / Double(steps.count)))
                        .animation(.easeInOut(duration: 0.4), value: currentStepIndex)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Instruction Section

    private var instructionSection: some View {
        VStack(spacing: 16) {
            Text(steps[currentStepIndex].description)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if showingZones {
                Text("Ahora Julia debe tocar la zona correcta")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingZones)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                playVibration()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 20, weight: .bold))

                    Text(showingZones ? "Reproducir de nuevo" : "Reproducir vibración")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .glassCardAccent(
                    cornerRadius: 28,
                    color: zoneColor(for: currentStepIndex)
                )
            }
            .buttonStyle(.plain)

            if showingZones {
                Button {
                    playVibration()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Repetir vibración")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .glassCard(cornerRadius: 20)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingZones)
    }

    // MARK: - Zones Section

    private var zonesSection: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let halfW = (geo.size.width - 12) / 2
                let halfH: CGFloat = showingZones ? 130 : 0

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        tutorialZone(index: 0, width: halfW, height: halfH)
                        tutorialZone(index: 1, width: halfW, height: halfH)
                    }
                    HStack(spacing: 12) {
                        tutorialZone(index: 2, width: halfW, height: halfH)
                        tutorialZone(index: 3, width: halfW, height: halfH)
                    }
                }
            }
            .frame(height: showingZones ? 272 : 0)
            .clipped()
            .animation(.easeInOut(duration: 0.4), value: showingZones)
        }
    }

    private func tutorialZone(index: Int, width: CGFloat, height: CGFloat) -> some View {
        TactileZone(
            index: index,
            width: width,
            height: height,
            isSelected: selectedZone == index
        ) {
            handleZoneTap(index)
        }
    }

    // MARK: - Helpers

    private func zoneColor(for index: Int) -> Color {
        let colors = ["34C759", "FF453A", "FF9500", "7B6EF6"]
        return Color(hex: colors[index])
    }

    private func playVibration() {
        let step = steps[currentStepIndex]
        HapticEngine.shared.play(word: step.hapticKey)

        if !showingZones {
            withAnimation {
                showingZones = true
            }
        }
    }

    private func handleZoneTap(_ index: Int) {
        let step = steps[currentStepIndex]
        selectedZone = index

        if index == step.expectedZone {
            HapticEngine.shared.play(word: "Bien")

            withAnimation {
                feedbackShown = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                advanceStep()
            }
        } else {
            HapticEngine.shared.play(word: "No")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation {
                    selectedZone = nil
                }
            }
        }
    }

    private func advanceStep() {
        withAnimation {
            selectedZone = nil
            feedbackShown = false
        }

        if currentStepIndex < steps.count - 1 {
            withAnimation {
                currentStepIndex += 1
                showingZones = false
            }
        } else {
            tutorialCompleted = true
            onComplete()
        }
    }
}

#Preview {
    TutorialView(onComplete: {})
}
