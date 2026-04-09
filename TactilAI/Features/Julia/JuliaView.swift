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

    // Detección de pánico: 3 toques rápidos en zona Emergencia
    @State private var emergencyTapTimestamps: [Date] = []
    @State private var panicTriggered: Bool = false
    @State private var emergencyService = EmergencyService()
    private let panicThreshold = 3
    private let panicWindow: TimeInterval = 1.5

    // Detección de shake desesperado: 3 shakes en 4 segundos → llamada directa
    @State private var shakeTimestamps: [Date] = []
    private let desperateShakeThreshold = 3
    private let desperateShakeWindow: TimeInterval = 4.0

    // Comandos de voz
    @State private var speechService = SpeechService()
    @State private var voiceCommandService = VoiceCommandService()
    @State private var voiceCommandFeedback: String?
    @State private var showVoiceOverlay: Bool = false
    @State private var lastProcessedTranscript: String = ""
    @State private var voiceDebounceTask: Task<Void, Never>?
    @State private var bubbleRing1: CGFloat = 1.0
    @State private var bubbleRing2: CGFloat = 1.0
    @State private var bubbleRing3: CGFloat = 1.0

    private let zones = TactileZoneData.zones

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
                    let halfH = (geo.size.height - 56) / 2

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

                // BOTÓN DE VOZ — grande y accesible al tacto
                voiceButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            // Burbuja de escucha activa
            if speechService.isListening {
                listeningBubble
            }

            // Overlay de confirmación
            if showOverlay && !speechService.isListening {
                overlayFlash
            }

            // Overlay de pánico activado
            if panicTriggered {
                panicOverlay
            }

            // Overlay de comando de voz detectado
            if showVoiceOverlay, let feedback = voiceCommandFeedback {
                voiceCommandOverlay(message: feedback)
            }
        }
        .fontDesign(.rounded)
        .onShake {
            handleShake()
        }
        .onChange(of: speechService.transcript) { _, newValue in
            processVoiceCommand(transcript: newValue)
        }
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

                    Text(speechService.isListening ? "Escuchando..." : "Toca o agita para hablar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(speechService.isListening ? Color(hex: "4ECDC4") : .white.opacity(0.5))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Zone Card

    private func zoneCard(index: Int, width: CGFloat, height: CGFloat) -> some View {
        let isActive = lastTapped == zones[index].label && showOverlay

        return TactileZone(
            index: index,
            width: width,
            height: height,
            isSelected: isActive
        ) {
            zoneTapped(label: zones[index].label, word: zones[index].word)
        }
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

        // Detección de pánico en zona Emergencia
        if label == "Emergencia" {
            checkPanicPattern()
        }

        // Registrar en modelo adaptativo
        let zoneIndex = zones.firstIndex(where: { $0.label == label }) ?? 0
        let patternID: String = switch zoneIndex {
        case 0: "yes"
        case 1: "no"
        case 2: "help"
        case 3: "sos"
        default: "yes"
        }
        AdaptivePatternModel.shared.recordInteraction(
            patternID: patternID,
            zone: zoneIndex,
            durationMs: Double.random(in: 200...600),
            pressureLevel: 0.6,
            responseTime: Double.random(in: 100...500),
            confirmedByCaregiver: false
        )

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

    // MARK: - Detección de pánico

    private func checkPanicPattern() {
        let now = Date()
        emergencyTapTimestamps.append(now)

        // Filtrar solo toques dentro de la ventana de tiempo
        emergencyTapTimestamps = emergencyTapTimestamps.filter {
            now.timeIntervalSince($0) <= panicWindow
        }

        // Si hay suficientes toques rápidos → pánico
        if emergencyTapTimestamps.count >= panicThreshold && !panicTriggered {
            panicTriggered = true
            emergencyTapTimestamps.removeAll()
            activatePanic()
        }
    }

    private func activatePanic() {
        HapticEngine.shared.play(word: "Pánico")

        if emergencyService.hasContact && emergencyService.canTrigger {
            emergencyService.triggerSOS()
        }

        // Reset después del cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            panicTriggered = false
        }
    }

    // MARK: - Listening Bubble

    private var listeningBubble: some View {
        ZStack {
            // Fondo oscuro sutil
            Color(hex: "07071A").opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Orbe central con anillos pulsantes
                ZStack {
                    // Anillo 3 — exterior, más tenue
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "7B6EF6").opacity(0.15),
                                    Color(hex: "4ECDC4").opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(bubbleRing3)
                        .opacity(Double(2.5 - bubbleRing3) / 1.5)

                    // Anillo 2 — medio
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "7B6EF6").opacity(0.25),
                                    Color(hex: "4ECDC4").opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(bubbleRing2)
                        .opacity(Double(2.5 - bubbleRing2) / 1.5)

                    // Anillo 1 — interior
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "7B6EF6").opacity(0.4),
                                    Color(hex: "4ECDC4").opacity(0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(bubbleRing1)
                        .opacity(Double(2.5 - bubbleRing1) / 1.5)

                    // Glow difuso
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "7B6EF6").opacity(0.20),
                                    Color(hex: "4ECDC4").opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(glowPhase ? 1.15 : 0.95)

                    // Orbe glass central
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.25),
                                            Color(hex: "7B6EF6").opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )

                    // Icono de micrófono
                    Image(systemName: "waveform")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "7B6EF6"), Color(hex: "4ECDC4")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(hex: "7B6EF6").opacity(0.5), radius: 12)
                }

                // Transcript en vivo
                VStack(spacing: 8) {
                    Text("Escuchando...")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "4ECDC4"))

                    if !speechService.transcript.isEmpty {
                        Text("\"\(speechService.transcript)\"")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Text("Di un comando: \"emergencia\", \"me duele la cabeza\"...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                // Botón para detener
                Button {
                    speechService.stopListening()
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: "FF453A"))
                            .frame(width: 10, height: 10)
                        Text("Detener")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .glassCard(cornerRadius: 20)
                }
            }
        }
        .transition(.opacity)
        .onAppear {
            startBubbleAnimation()
        }
        .onDisappear {
            resetBubbleAnimation()
        }
    }

    private func startBubbleAnimation() {
        bubbleRing1 = 1.0
        bubbleRing2 = 1.0
        bubbleRing3 = 1.0

        // Anillo 1 — rápido
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
            bubbleRing1 = 2.2
        }
        // Anillo 2 — medio, con delay
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(0.4)) {
            bubbleRing2 = 2.2
        }
        // Anillo 3 — lento, con más delay
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(0.8)) {
            bubbleRing3 = 2.2
        }
    }

    private func resetBubbleAnimation() {
        bubbleRing1 = 1.0
        bubbleRing2 = 1.0
        bubbleRing3 = 1.0
    }

    // MARK: - Voice Button

    private var voiceButton: some View {
        Button {
            handleVoiceTap()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    if speechService.isListening {
                        // Onda pulsante cuando escucha
                        Circle()
                            .fill(Color(hex: "7B6EF6").opacity(0.3))
                            .frame(width: 32, height: 32)
                            .scaleEffect(glowPhase ? 1.5 : 1.0)

                        Circle()
                            .fill(Color(hex: "FF453A").opacity(0.3))
                            .frame(width: 24, height: 24)
                            .scaleEffect(glowPhase ? 1.8 : 1.0)
                    }

                    Image(systemName: speechService.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(speechService.isListening ? Color(hex: "FF453A") : Color(hex: "7B6EF6"))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(speechService.isListening ? "Escuchando..." : "Comandos de voz")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if !speechService.isListening {
                        Text("Agita el teléfono o toca aquí")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }

                Spacer()

                if speechService.isListening {
                    Text(speechService.transcript.isEmpty ? "Di algo..." : speechService.transcript)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .frame(maxWidth: 120, alignment: .trailing)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .glassCardAccent(
                cornerRadius: 28,
                color: speechService.isListening ? Color(hex: "FF453A") : Color(hex: "7B6EF6")
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speechService.isListening ? "Escuchando. Toca para detener" : "Activar comandos de voz")
    }

    // MARK: - Voice Command Overlay

    private func voiceCommandOverlay(message: String) -> some View {
        ZStack {
            Color(hex: "4ECDC4").opacity(0.2)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color(hex: "4ECDC4"))
                    .shadow(color: Color(hex: "4ECDC4").opacity(0.5), radius: 14)

                Text(message)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .glassCard()
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    // MARK: - Shake Detection

    private func handleShake() {
        let now = Date()
        shakeTimestamps.append(now)

        // Filtrar solo shakes dentro de la ventana de tiempo
        shakeTimestamps = shakeTimestamps.filter {
            now.timeIntervalSince($0) <= desperateShakeWindow
        }

        // Shake desesperado: 3+ shakes rápidos → llamada directa
        if shakeTimestamps.count >= desperateShakeThreshold && !panicTriggered {
            shakeTimestamps.removeAll()
            panicTriggered = true
            HapticEngine.shared.play(word: "Pánico")

            // Detener escucha si estaba activa
            if speechService.isListening {
                speechService.stopListening()
            }

            // Llamada directa sin confirmación
            if emergencyService.hasContact {
                emergencyService.triggerSOS()
            }

            // Reset después del cooldown
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                panicTriggered = false
            }
            return
        }

        // Shake normal: activa escucha de voz
        if !speechService.isListening && !panicTriggered {
            handleVoiceTap()
        }
    }

    // MARK: - Voice Actions

    private func handleVoiceTap() {
        if speechService.isListening {
            speechService.stopListening()
        } else {
            // Confirmación háptica al activar
            HapticEngine.shared.play(word: "Bien")
            lastProcessedTranscript = ""
            Task {
                let granted = await speechService.requestPermission()
                if granted {
                    try? speechService.startListening()
                }
            }
        }
    }

    private func processVoiceCommand(transcript: String) {
        guard !transcript.isEmpty else { return }

        // Cancelar el debounce anterior — cada cambio reinicia el timer
        voiceDebounceTask?.cancel()

        // Esperar 1.2s de silencio para que la frase se complete
        voiceDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))

            // Verificar que no fue cancelado y que seguimos escuchando
            guard !Task.isCancelled,
                  speechService.isListening || !transcript.isEmpty,
                  transcript != lastProcessedTranscript else { return }

            guard let command = voiceCommandService.detectCommand(in: transcript) else { return }

            // Marcar como procesado y detener escucha
            lastProcessedTranscript = transcript
            speechService.stopListening()

            switch command {
            case .sos:
                voiceCommandFeedback = "SOS Activado"
                HapticEngine.shared.play(word: "Pánico")
                if emergencyService.hasContact && emergencyService.canTrigger {
                    emergencyService.triggerSOS()
                }

            case .distress(let message):
                voiceCommandFeedback = "Enviando: \(message)"
                HapticEngine.shared.play(word: "Ayuda")
                emergencyService.sendDistressMessage(message)

            case .yes:
                voiceCommandFeedback = "Sí"
                HapticEngine.shared.play(word: "Sí")

            case .no:
                voiceCommandFeedback = "No"
                HapticEngine.shared.play(word: "No")
            }

            // Mostrar overlay de confirmación
            withAnimation(.easeIn(duration: 0.15)) {
                showVoiceOverlay = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showVoiceOverlay = false
                    voiceCommandFeedback = nil
                }
            }
        }
    }

    // MARK: - Panic Overlay

    private var panicOverlay: some View {
        ZStack {
            Color(hex: "FF453A").opacity(0.35)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 12) {
                Image(systemName: "phone.arrow.up.right.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color(hex: "FF453A"))
                    .shadow(color: Color(hex: "FF453A").opacity(0.6), radius: 16)

                Text("SOS Activado")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Llamando al contacto de emergencia")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(28)
            .glassCard()
        }
        .transition(.opacity)
        .allowsHitTesting(false)
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
