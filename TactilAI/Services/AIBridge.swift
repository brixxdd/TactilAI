// AIBridge.swift
// TactilAI
//
// Puente con FoundationModels de Apple para simplificar mensajes
// al vocabulario táctil y clasificar urgencia on-device.
// Incluye fallback simulado si el modelo no está disponible.

import Foundation
import Observation
import FoundationModels

enum UrgencyLevel: String {
    case normal
    case importante
    case emergencia
}

@Observable
class AIBridge {

    var isProcessing: Bool = false
    var simplifiedMessage: String = ""

    /// Verifica si el modelo on-device está disponible
    private var modelAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    // MARK: - Simplificar mensaje

    /// Simplifica un mensaje largo al vocabulario táctil del usuario.
    /// Si el modelo no está disponible, usa fallback con las primeras 3 palabras.
    func simplify(message: String, vocabulary: [String]) async -> String {
        guard !message.isEmpty else { return "" }

        isProcessing = true
        defer { isProcessing = false }

        guard modelAvailable else {
            return fallbackSimplify(message: message)
        }

        do {
            let vocabList = vocabulary.joined(separator: ", ")
            let session = LanguageModelSession(instructions: """
                Eres un asistente de comunicación táctil para personas sordociegas. \
                Simplificas mensajes usando SOLO palabras del vocabulario proporcionado. \
                Responde ÚNICAMENTE con la frase simplificada, máximo 4 palabras. \
                Sin explicaciones adicionales.
                """)

            let prompt = """
                Vocabulario táctil disponible: [\(vocabList)].
                Simplifica este mensaje: \(message).
                Responde solo la frase simplificada.
                """

            let response = try await session.respond(to: prompt)
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            simplifiedMessage = result
            return result
        } catch {
            let fallback = fallbackSimplify(message: message)
            simplifiedMessage = fallback
            return fallback
        }
    }

    // MARK: - Clasificar urgencia

    /// Clasifica la urgencia de un mensaje: normal, importante, o emergencia.
    /// Si el modelo no está disponible, busca palabras clave.
    func classifyUrgency(message: String) async -> UrgencyLevel {
        guard !message.isEmpty else { return .normal }

        isProcessing = true
        defer { isProcessing = false }

        guard modelAvailable else {
            return fallbackClassify(message: message)
        }

        do {
            let session = LanguageModelSession(instructions: """
                Clasifica mensajes por urgencia. \
                Responde con UNA sola palabra: normal, importante, o emergencia. \
                Sin explicaciones.
                """)

            let prompt = "Clasifica la urgencia: \(message)"
            let response = try await session.respond(to: prompt)
            let result = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if result.contains("emergencia") {
                return .emergencia
            } else if result.contains("importante") {
                return .importante
            }
            return .normal
        } catch {
            return fallbackClassify(message: message)
        }
    }

    // MARK: - Fallbacks

    /// Fallback: toma las primeras 3 palabras del mensaje
    private func fallbackSimplify(message: String) -> String {
        let words = message.split(separator: " ").prefix(3)
        let result = words.joined(separator: " ")
        simplifiedMessage = result
        return result
    }

    /// Fallback: busca palabras clave de urgencia
    private func fallbackClassify(message: String) -> UrgencyLevel {
        let lower = message.lowercased()
        let emergencyWords = ["emergencia", "ayuda", "sos", "urgente", "peligro", "dolor", "caída"]
        let importantWords = ["necesito", "importante", "pronto", "rápido", "mal"]

        if emergencyWords.contains(where: { lower.contains($0) }) {
            return .emergencia
        }
        if importantWords.contains(where: { lower.contains($0) }) {
            return .importante
        }
        return .normal
    }
}
