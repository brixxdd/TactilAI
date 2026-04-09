// CaregiverView.swift
// TactilAI
//
// Vista principal del cuidador — Liquid Glass con animaciones.

import SwiftUI

struct CaregiverView: View {

    @State var messageText = ""
    @State var selectedPattern = "Buenos días"
    @State var simplifiedMessage = ""
    @State private var speechService = SpeechService()
    @State private var aiBridge = AIBridge()
    @State private var showPermissionAlert = false
    @State private var animatePreview = false
    @State private var glowPhase = false
    @State private var orbOffset1: CGFloat = 0
    @State private var orbOffset2: CGFloat = 0
    @State private var barHeights: [CGFloat] = [22, 22, 10, 38, 10, 22, 22]
    @State private var isSending = false
    @State private var selectedChipIndex: Int? = nil
    @AppStorage("tutorialCompleted") private var tutorialCompleted = true
    @FocusState private var isTextFieldFocused: Bool
    @ObservedObject private var adaptiveModel = AdaptivePatternModel.shared

    private let vocabulary = ["Buenos días", "¿Cómo estás?", "Hora de comer", "¿Dormiste bien?"]

    private let chips: [(String, String, String)] = [
        ("Buenos días", "7B6EF6", "sun.max.fill"),
        ("¿Cómo estás?", "4ECDC4", "heart.fill"),
        ("Hora de comer", "FF9500", "fork.knife"),
        ("¿Dormiste bien?", "A78BFA", "moon.stars.fill")
    ]

    var body: some View {
        ZStack {
            Color(hex: "07071A")
                .ignoresSafeArea()

            // AMBIENT ORBS animados
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "7B6EF6").opacity(0.22), Color(hex: "7B6EF6").opacity(0.0)],
                        center: .center, startRadius: 20, endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .offset(x: -80 + orbOffset1, y: -80)
                .blur(radius: 60)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "4ECDC4").opacity(0.16), Color(hex: "4ECDC4").opacity(0.0)],
                        center: .center, startRadius: 10, endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .offset(x: 140 + orbOffset2, y: 380)
                .blur(radius: 50)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FF9500").opacity(0.10), .clear],
                        center: .center, startRadius: 5, endRadius: 100
                    )
                )
                .frame(width: 180, height: 180)
                .offset(x: 60, y: 160)
                .blur(radius: 40)

            // CONTENIDO
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    headerSection
                    profileCard
                    quickMessagesSection
                    composeCard
                    hapticPreviewCard
                    aiStatsCard
                    emergencyButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isTextFieldFocused = false }
        }
        .onChange(of: speechService.transcript) { _, newValue in
            messageText = newValue
        }
        .alert("Micrófono no disponible", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Ve a Configuración > TactilAI > Micrófono para activar")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowPhase = true
                orbOffset1 = 15
                orbOffset2 = -12
            }
        }
    }

    // MARK: - 1. Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    Text("Tactil")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    Text("AI")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "7B6EF6"), Color(hex: "4ECDC4")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                }

                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "4ECDC4").opacity(0.4))
                            .frame(width: 14, height: 14)
                            .scaleEffect(glowPhase ? 1.6 : 0.8)
                            .opacity(glowPhase ? 0.0 : 0.6)

                        Circle()
                            .fill(Color(hex: "4ECDC4"))
                            .frame(width: 8, height: 8)
                    }

                    Text("Julia conectada")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "4ECDC4"))
                }
            }
            Spacer()

            // Menú de settings
            Menu {
                Button {
                    tutorialCompleted = false
                } label: {
                    Label("Repetir tutorial", systemImage: "arrow.counterclockwise")
                }
            } label: {
                ZStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "7B6EF6").opacity(0.3))
                        .blur(radius: 6)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.top, 56)
    }

    // MARK: - 2. Perfil Card

    private var profileCard: some View {
        HStack(spacing: 14) {
            // Avatar con gradiente y glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "7B6EF6").opacity(0.4), .clear],
                            center: .center, startRadius: 10, endRadius: 38
                        )
                    )
                    .frame(width: 66, height: 66)
                    .scaleEffect(glowPhase ? 1.1 : 1.0)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "7B6EF6"), Color(hex: "5B4ED6")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Text("JM")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Julia Mendoza")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("58 años · Síndrome de Usher")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            // Pill con glow
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: "4ECDC4"))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(hex: "4ECDC4").opacity(0.6), radius: 4)
                Text("En reposo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "4ECDC4"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "4ECDC4").opacity(0.12))
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "4ECDC4").opacity(0.5), Color(hex: "4ECDC4").opacity(0.15)],
                            startPoint: .top, endPoint: .bottom
                        ), lineWidth: 1
                    )
            )
            .clipShape(Capsule())
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - 3. Mensajes Rápidos

    private var quickMessagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "7B6EF6"))
                Text("Mensajes rápidos")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(0..<chips.count, id: \.self) { index in
                    let chip = chips[index]
                    let color = Color(hex: chip.1)
                    let isSelected = selectedChipIndex == index

                    Button {
                        messageText = chip.0
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedPattern = chip.0
                            selectedChipIndex = index
                            animatePreview.toggle()
                            randomizeBars()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: chip.2)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(color)
                                .shadow(color: color.opacity(0.5), radius: isSelected ? 6 : 0)

                            Text(chip.0)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .glassCardAccent(cornerRadius: 22, color: color)
                        .scaleEffect(isSelected ? 0.96 : 1.0)
                    }
                }
            }
        }
    }

    // MARK: - 4. Compose Card

    private var composeCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                // TextField
                HStack {
                    TextField("Escribe un mensaje...", text: $messageText)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .focused($isTextFieldFocused)
                        .submitLabel(.send)
                        .onSubmit { sendMessage() }

                    if !messageText.isEmpty {
                        Button {
                            withAnimation { messageText = "" }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 16)

                // Botón envío con gradiente
                Button {
                    sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "7B6EF6"), Color(hex: "5B4ED6")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)
                            .shadow(color: Color(hex: "7B6EF6").opacity(messageText.isEmpty ? 0 : 0.4), radius: 8)

                        if isSending {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .disabled(messageText.isEmpty || isSending)
                .opacity(messageText.isEmpty ? 0.35 : 1.0)
                .scaleEffect(messageText.isEmpty ? 0.9 : 1.0)
                .animation(.spring(response: 0.3), value: messageText.isEmpty)
            }

            // Botones secundarios
            HStack(spacing: 10) {
                // Botón micrófono
                Button {
                    handleMicTap()
                } label: {
                    HStack(spacing: 7) {
                        ZStack {
                            if speechService.isListening {
                                Circle()
                                    .fill(Color(hex: "FF453A").opacity(0.3))
                                    .frame(width: 24, height: 24)
                                    .scaleEffect(glowPhase ? 1.4 : 1.0)
                            }
                            Image(systemName: speechService.isListening ? "waveform" : "mic.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(speechService.isListening ? "Escuchando..." : "Dictar voz")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(speechService.isListening ? Color(hex: "FF453A") : Color(hex: "7B6EF6"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .glassCardAccent(
                        cornerRadius: 14,
                        color: speechService.isListening ? Color(hex: "FF453A") : Color(hex: "7B6EF6")
                    )
                }

                // Botón escanear
                Button {
                    // Escanear
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Escanear")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "4ECDC4"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .glassCardAccent(cornerRadius: 14, color: Color(hex: "4ECDC4"))
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - 5. Haptic Preview Card

    private var hapticPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform.path")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "7B6EF6"))
                Text("Vista previa")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(selectedPattern)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "7B6EF6"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "7B6EF6").opacity(0.12))
                    .clipShape(Capsule())
            }

            // Barras animadas con gradiente
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<barHeights.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "7B6EF6"),
                                    Color(hex: "4ECDC4").opacity(0.7)
                                ],
                                startPoint: .bottom, endPoint: .top
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeights[index])
                        .shadow(color: Color(hex: "7B6EF6").opacity(0.3), radius: 4, y: 2)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.05),
                            value: barHeights
                        )
                }
            }
            .frame(height: 50)
            .padding(.vertical, 4)

            // Línea de tiempo
            HStack {
                ForEach(0..<barHeights.count, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: "7B6EF6").opacity(barHeights[index] > 20 ? 0.8 : 0.2))
                        .frame(width: 4, height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .glassCardAccent(color: Color(hex: "7B6EF6"))
    }

    // MARK: - 6. AI Stats Card

    private var aiStatsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "4ECDC4"))
                Text("IA Adaptativa")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()

                // Status pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(aiStatusColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: aiStatusColor.opacity(0.6), radius: 4)
                    Text(adaptiveModel.modelStatus.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(aiStatusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(aiStatusColor.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(aiStatusColor.opacity(0.3), lineWidth: 1)
                )
                .clipShape(Capsule())
            }

            // Accuracy + Interactions row
            HStack(spacing: 16) {
                // Accuracy
                VStack(spacing: 6) {
                    Text("\(Int(adaptiveModel.modelAccuracy * 100))%")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4ECDC4"), Color(hex: "7B6EF6")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    Text("Precisión")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 40)

                // Interactions
                VStack(spacing: 6) {
                    Text("\(adaptiveModel.interactionCount)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Interacciones")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)

            // Adaptation progress
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Adaptación")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text("\(Int(adaptiveModel.adaptationProgress * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "7B6EF6"))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "7B6EF6"), Color(hex: "4ECDC4")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * adaptiveModel.adaptationProgress)
                            .shadow(color: Color(hex: "7B6EF6").opacity(0.4), radius: 4)
                            .animation(.easeInOut(duration: 0.5), value: adaptiveModel.adaptationProgress)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .glassCardAccent(color: Color(hex: "4ECDC4"))
    }

    private var aiStatusColor: Color {
        switch adaptiveModel.modelStatus {
        case .ready, .coreMLReady: return Color(hex: "4ECDC4")
        case .training:            return Color(hex: "FF9500")
        case .notTrained:          return Color(hex: "7B6EF6")
        case .error:               return Color(hex: "FF453A")
        }
    }

    // MARK: - 7. Emergencia

    private var emergencyButton: some View {
        Button {
            // Emergencia
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: "FF453A").opacity(0.4))
                        .blur(radius: 6)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "FF6B6B"))
                }
                Text("Enviar emergencia")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "FF6B6B"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .glassCardAccent(cornerRadius: 24, color: Color(hex: "FF453A"))
        }
    }

    // MARK: - Acciones

    private func sendMessage() {
        isTextFieldFocused = false
        let text = messageText
        messageText = ""
        isSending = true
        Task {
            let result = await aiBridge.simplify(message: text, vocabulary: vocabulary)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                selectedPattern = result.isEmpty ? text : result
                isSending = false
                animatePreview.toggle()
                randomizeBars()
            }

            // Registrar interacción en el modelo adaptativo
            let patternID = mapToPatternID(text)
            adaptiveModel.recordInteraction(
                patternID: patternID,
                zone: mapToZone(patternID),
                durationMs: Double.random(in: 300...800),
                pressureLevel: 0.5,
                responseTime: 0,
                confirmedByCaregiver: true
            )
        }
    }

    private func mapToPatternID(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("buenos") || lower.contains("hola") { return "greeting" }
        if lower.contains("cómo") || lower.contains("estás") { return "greeting" }
        if lower.contains("comer") || lower.contains("hora") { return "help" }
        if lower.contains("dormiste") || lower.contains("bien") { return "yes" }
        return "greeting"
    }

    private func mapToZone(_ patternID: String) -> Int {
        switch patternID {
        case "yes": return 0
        case "no": return 1
        case "help": return 2
        case "sos": return 3
        default: return 0
        }
    }

    private func handleMicTap() {
        if speechService.isListening {
            speechService.stopListening()
        } else {
            Task {
                let granted = await speechService.requestPermission()
                if granted {
                    do {
                        try speechService.startListening()
                    } catch {
                        print("Error al iniciar escucha: \(error)")
                    }
                } else {
                    showPermissionAlert = true
                }
            }
        }
    }

    private func randomizeBars() {
        barHeights = (0..<7).map { _ in CGFloat.random(in: 8...50) }
    }
}

// MARK: - Glass Modifiers

extension View {
    func glassCard(cornerRadius: CGFloat = 24) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    func glassCardAccent(
        cornerRadius: CGFloat = 24,
        color: Color = Color(hex: "7B6EF6")
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(0.35),
                                color.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

#Preview {
    CaregiverView()
}
