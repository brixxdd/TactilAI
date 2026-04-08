// VoiceCommandService.swift
// TactilAI
//
// Detecta comandos de voz en el transcript del SpeechService
// y ejecuta acciones de emergencia o malestar.
// Diseñado para personas sordociegas que pueden hablar.

import Foundation
import Observation

/// Resultado de un comando de voz detectado
enum VoiceCommand: Equatable {
    case sos                        // "emergencia", "socorro", "ayuda"
    case distress(String)           // "me duele la cabeza", "no puedo respirar", etc.
    case yes                        // "sí", "bien"
    case no                         // "no"
}

@Observable
final class VoiceCommandService {

    // MARK: - Comandos reconocidos

    /// Palabras clave → comando SOS (prioridad alta)
    private let sosKeywords = ["emergencia", "socorro", "ayuda urgente", "auxilio", "pánico"]

    /// Frases de malestar → se envían como SMS
    private let distressPatterns: [(keywords: [String], message: String)] = [
        (["duele", "cabeza"], "Me duele mucho la cabeza"),
        (["no puedo respirar", "respirar", "ahogo"], "No puedo respirar bien"),
        (["siento mal", "me siento mal", "estoy mal"], "Me siento muy mal"),
        (["medicina", "medicamento", "pastilla"], "Necesito mi medicina")
    ]

    /// Palabras de respuesta simple
    private let yesKeywords = ["sí", "bien", "ok", "bueno"]
    private let noKeywords = ["no"]

    // MARK: - Detectar comando en texto

    /// Analiza el transcript y devuelve el comando detectado, si hay alguno.
    /// Prioridad: SOS > malestar > sí/no
    func detectCommand(in transcript: String) -> VoiceCommand? {
        let text = transcript.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return nil }

        // 1. SOS — prioridad máxima
        for keyword in sosKeywords {
            if text.contains(keyword) {
                return .sos
            }
        }

        // 2. Mensajes de malestar
        for pattern in distressPatterns {
            for keyword in pattern.keywords {
                if text.contains(keyword) {
                    return .distress(pattern.message)
                }
            }
        }

        // 3. Respuestas simples — solo si la frase es corta (máx 3 palabras)
        //    Evita falsos positivos: "no puedo respirar" no debe disparar .no
        let wordCount = text.split(separator: " ").count
        if wordCount <= 3 {
            for keyword in yesKeywords {
                if text == keyword || text.hasSuffix(" \(keyword)") {
                    return .yes
                }
            }

            for keyword in noKeywords {
                if text == keyword {
                    return .no
                }
            }
        }

        return nil
    }
}
