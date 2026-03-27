// HapticPattern.swift
// TactilAI
//
// Modelo que define los patrones hápticos utilizados para comunicación táctil.
// Cada patrón es una secuencia de pulsos con intensidad, nitidez y duración
// específicas que transmiten información al usuario mediante vibraciones.

import Foundation

/// Un pulso individual dentro de un patrón háptico
struct HapticPulse: Codable {
    /// Fuerza del pulso (0.0 a 1.0)
    var intensity: Float
    /// Nitidez/textura del pulso (0.0 suave → 1.0 agudo)
    var sharpness: Float
    /// Duración del pulso en segundos
    var duration: TimeInterval
    /// Momento de inicio relativo al comienzo del patrón (en segundos)
    var relativeTime: TimeInterval
}

/// Representa un patrón háptico compuesto por una secuencia de pulsos
struct HapticPattern: Identifiable, Codable {
    let id: UUID
    var name: String
    var pulses: [HapticPulse]
    
    /// Duración total del patrón (fin del último pulso)
    var totalDuration: TimeInterval {
        pulses.map { $0.relativeTime + $0.duration }.max() ?? 0
    }
    
    init(id: UUID = UUID(), name: String, pulses: [HapticPulse]) {
        self.id = id
        self.name = name
        self.pulses = pulses
    }
}

// MARK: - Patrones base de comunicación táctil

extension HapticPattern {
    
    /// "Sí" — Dos golpes firmes y breves, como un asentimiento con la cabeza
    static let si = HapticPattern(name: "Sí", pulses: [
        HapticPulse(intensity: 0.8, sharpness: 0.5, duration: 0.12, relativeTime: 0.0),
        HapticPulse(intensity: 0.9, sharpness: 0.6, duration: 0.12, relativeTime: 0.2)
    ])
    
    /// "No" — Tres pulsos rápidos y agudos, como una negación enérgica
    static let no = HapticPattern(name: "No", pulses: [
        HapticPulse(intensity: 0.7, sharpness: 0.9, duration: 0.08, relativeTime: 0.0),
        HapticPulse(intensity: 0.8, sharpness: 1.0, duration: 0.08, relativeTime: 0.12),
        HapticPulse(intensity: 0.7, sharpness: 0.9, duration: 0.08, relativeTime: 0.24)
    ])
    
    /// "Ayuda" — Pulso largo sostenido seguido de tres ráfagas cortas (tipo SOS)
    static let ayuda = HapticPattern(name: "Ayuda", pulses: [
        HapticPulse(intensity: 1.0, sharpness: 0.4, duration: 0.4,  relativeTime: 0.0),
        HapticPulse(intensity: 0.9, sharpness: 0.8, duration: 0.1,  relativeTime: 0.55),
        HapticPulse(intensity: 0.9, sharpness: 0.8, duration: 0.1,  relativeTime: 0.75),
        HapticPulse(intensity: 0.9, sharpness: 0.8, duration: 0.1,  relativeTime: 0.95)
    ])
    
    /// "Bien" — Onda suave ascendente, sensación cálida y positiva
    static let bien = HapticPattern(name: "Bien", pulses: [
        HapticPulse(intensity: 0.3, sharpness: 0.2, duration: 0.15, relativeTime: 0.0),
        HapticPulse(intensity: 0.5, sharpness: 0.3, duration: 0.15, relativeTime: 0.18),
        HapticPulse(intensity: 0.7, sharpness: 0.4, duration: 0.2,  relativeTime: 0.36),
        HapticPulse(intensity: 0.9, sharpness: 0.5, duration: 0.3,  relativeTime: 0.58)
    ])
    
    /// "Necesito" — Dos pulsos medios insistentes, llamada de atención
    static let necesito = HapticPattern(name: "Necesito", pulses: [
        HapticPulse(intensity: 0.6, sharpness: 0.5, duration: 0.25, relativeTime: 0.0),
        HapticPulse(intensity: 0.8, sharpness: 0.6, duration: 0.25, relativeTime: 0.35),
        HapticPulse(intensity: 1.0, sharpness: 0.7, duration: 0.3,  relativeTime: 0.70)
    ])
    
    /// Todos los patrones base disponibles
    static let allBase: [HapticPattern] = [.si, .no, .ayuda, .bien, .necesito]
}
