// HapticEngine.swift
// TactilAI
//
// Singleton que gestiona CoreHaptics para reproducir patrones táctiles.
// Incluye fallback con UIKit haptics para mayor confiabilidad.
// Los hápticos solo funcionan en dispositivo físico;
// en simulador no hay error pero tampoco vibración.

import Foundation
import CoreHaptics
import UIKit

final class HapticEngine {

    static let shared = HapticEngine()

    private var engine: CHHapticEngine?
    private var isReady = false
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

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
        guard supportsHaptics else {
            print("[HapticEngine] Dispositivo no soporta hápticos")
            return
        }

        let engine = try CHHapticEngine()
        engine.isAutoShutdownEnabled = false
        engine.playsHapticsOnly = true

        engine.stoppedHandler = { [weak self] reason in
            print("[HapticEngine] Motor detenido: \(reason)")
            self?.isReady = false
        }

        engine.resetHandler = { [weak self] in
            print("[HapticEngine] Reset solicitado, reiniciando...")
            do {
                try self?.engine?.start()
                self?.isReady = true
                print("[HapticEngine] Reinicio exitoso")
            } catch {
                print("[HapticEngine] Error al reiniciar: \(error)")
                self?.isReady = false
            }
        }

        try await engine.start()
        self.engine = engine
        self.isReady = true
        print("[HapticEngine] Motor listo")
    }

    // MARK: - Reproducir patrón por palabra

    /// Busca el patrón asociado a la palabra y lo ejecuta.
    /// Palabras válidas: "Sí", "No", "Ayuda", "Bien", "Pánico".
    /// "Emergencia" se reproduce como "Ayuda".
    /// Si CoreHaptics falla, usa UIKit haptics como fallback.
    func play(word: String) {
        // "Emergencia" usa el mismo patrón que "Ayuda"
        let key = word == "Emergencia" ? "Ayuda" : word

        // Intentar reiniciar el motor si no está listo
        if !isReady, let engine {
            do {
                try engine.start()
                isReady = true
                print("[HapticEngine] Motor reiniciado en play()")
            } catch {
                print("[HapticEngine] No se pudo reiniciar, usando fallback")
                playFallback(key: key)
                return
            }
        }

        guard let engine, isReady else {
            print("[HapticEngine] Motor no disponible, usando fallback")
            playFallback(key: key)
            return
        }

        guard let pulses = patterns[key] else {
            print("[HapticEngine] Patrón '\(key)' no encontrado")
            return
        }

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
            print("[HapticEngine] Error CoreHaptics '\(word)': \(error), usando fallback")
            playFallback(key: key)
        }
    }

    // MARK: - Fallback UIKit Haptics

    /// Reproduce vibración usando UIKit como respaldo cuando CoreHaptics falla.
    private func playFallback(key: String) {
        switch key {
        case "Sí":
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                gen.impactOccurred()
            }
        case "No":
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.error)
        case "Ayuda":
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.prepare()
            gen.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                gen.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    gen.impactOccurred()
                }
            }
        case "Bien":
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.prepare()
            gen.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                gen.impactOccurred()
            }
        case "Pánico":
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.prepare()
            for i in 0..<5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    gen.impactOccurred(intensity: 1.0)
                }
            }
        default:
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()
        }
    }

    // MARK: - Detener

    /// Detiene el motor háptico y libera recursos.
    func stop() {
        engine?.stop(completionHandler: { _ in })
        isReady = false
    }
}
