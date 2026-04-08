// HapticEngine.swift
// TactilAI
//
// Singleton que gestiona CoreHaptics para reproducir patrones táctiles.
// Los hápticos solo funcionan en dispositivo físico;
// en simulador no hay error pero tampoco vibración.

import Foundation
import CoreHaptics

final class HapticEngine {

    static let shared = HapticEngine()

    private var engine: CHHapticEngine?
    private var isReady = false

    // Diccionario de patrones: palabra → definición de pulsos
    private let patterns: [String: [(intensity: Float, sharpness: Float, duration: TimeInterval, relativeTime: TimeInterval)]] = [
        // "Sí" — 2 pulsos cortos, intensidad 0.7, duración 0.15s, separados 0.2s
        "Sí": [
            (intensity: 0.7, sharpness: 0.5, duration: 0.15, relativeTime: 0.0),
            (intensity: 0.7, sharpness: 0.5, duration: 0.15, relativeTime: 0.2)
        ],
        // "No" — 1 pulso largo, intensidad 0.9, duración 0.5s
        "No": [
            (intensity: 0.9, sharpness: 0.7, duration: 0.5, relativeTime: 0.0)
        ],
        // "Ayuda" — 3 pulsos fuertes rápidos, intensidad 1.0, duración 0.1s, separados 0.15s
        "Ayuda": [
            (intensity: 1.0, sharpness: 0.8, duration: 0.1, relativeTime: 0.0),
            (intensity: 1.0, sharpness: 0.8, duration: 0.1, relativeTime: 0.15),
            (intensity: 1.0, sharpness: 0.8, duration: 0.1, relativeTime: 0.30)
        ],
        // "Bien" — 2 pulsos suaves, intensidad 0.5, duración 0.2s, separados 0.25s
        "Bien": [
            (intensity: 0.5, sharpness: 0.3, duration: 0.2, relativeTime: 0.0),
            (intensity: 0.5, sharpness: 0.3, duration: 0.2, relativeTime: 0.25)
        ],
        // "Pánico" — 5 pulsos fuertes muy rápidos, señal inequívoca de emergencia
        "Pánico": [
            (intensity: 1.0, sharpness: 1.0, duration: 0.12, relativeTime: 0.0),
            (intensity: 1.0, sharpness: 1.0, duration: 0.12, relativeTime: 0.15),
            (intensity: 1.0, sharpness: 1.0, duration: 0.12, relativeTime: 0.30),
            (intensity: 1.0, sharpness: 1.0, duration: 0.12, relativeTime: 0.45),
            (intensity: 1.0, sharpness: 1.0, duration: 0.12, relativeTime: 0.60)
        ]
    ]

    private init() {}

    // MARK: - Preparar el motor

    /// Inicializa y arranca CHHapticEngine.
    /// Llamar antes de reproducir cualquier patrón.
    func prepare() async throws {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        let engine = try CHHapticEngine()

        engine.stoppedHandler = { [weak self] _ in
            self?.isReady = false
        }

        engine.resetHandler = { [weak self] in
            do {
                try self?.engine?.start()
                self?.isReady = true
            } catch {
                self?.isReady = false
            }
        }

        try await engine.start()
        self.engine = engine
        self.isReady = true
    }

    // MARK: - Reproducir patrón por palabra

    /// Busca el patrón asociado a la palabra y lo ejecuta.
    /// Palabras válidas: "Sí", "No", "Ayuda", "Bien".
    /// "Emergencia" se reproduce como "Ayuda".
    func play(word: String) {
        guard isReady, let engine else { return }

        // "Emergencia" usa el mismo patrón que "Ayuda"
        let key = word == "Emergencia" ? "Ayuda" : word
        guard let pulses = patterns[key] else { return }

        let events: [CHHapticEvent] = pulses.map { pulse in
            let intensity = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: pulse.intensity
            )
            let sharpness = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: pulse.sharpness
            )
            return CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [intensity, sharpness],
                relativeTime: pulse.relativeTime,
                duration: pulse.duration
            )
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Error al reproducir patrón '\(word)': \(error.localizedDescription)")
        }
    }

    // MARK: - Detener

    /// Detiene el motor háptico y libera recursos.
    func stop() {
        engine?.stop(completionHandler: { _ in })
        isReady = false
    }
}
