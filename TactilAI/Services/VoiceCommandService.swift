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
    private let sosKeywords = [
        "emergencia", "socorro", "ayuda urgente", "auxilio", "pánico",
        "ayuda", "necesito ayuda", "por favor ayuda", "alguien ayúdeme",
        "necesito a alguien", "que venga alguien", "vengan", "llamen",
        "ayúdenme", "ayúdame", "ven rápido", "ven por favor",
        "necesito que vengas", "estoy en peligro", "tengo miedo",
        "no me dejen sola", "no me dejen solo", "por favor vengan"
    ]

    /// Frases de malestar → llamada al contacto
    private let distressPatterns: [(keywords: [String], message: String)] = [
        (["duele", "cabeza", "dolor de cabeza", "jaqueca", "migraña"], "Me duele mucho la cabeza"),
        (["no puedo respirar", "respirar", "ahogo", "me ahogo", "falta aire", "no respiro", "me falta el aire"], "No puedo respirar bien"),
        (["siento mal", "me siento mal", "estoy mal", "no estoy bien", "me siento enfermo", "me siento enferma", "estoy enfermo", "estoy enferma"], "Me siento muy mal"),
        (["medicina", "medicamento", "pastilla", "pastillas", "necesito medicina", "mi medicina", "mi medicamento", "me toca la medicina"], "Necesito mi medicina"),
        (["mareo", "mareado", "mareada", "me mareo", "estoy mareado", "vértigo", "todo da vueltas"], "Me siento mareado/a"),
        (["dolor", "me duele", "tengo dolor", "duele mucho"], "Tengo un dolor fuerte"),
        (["caí", "caída", "me caí", "tropecé", "estoy en el suelo", "no me puedo levantar"], "Me caí y necesito ayuda"),
        (["hambre", "tengo hambre", "quiero comer", "necesito comer", "no he comido"], "Tengo hambre, necesito comer"),
        (["sed", "tengo sed", "quiero agua", "necesito agua", "dame agua"], "Tengo sed, necesito agua"),
        (["frío", "tengo frío", "hace frío", "estoy temblando"], "Tengo mucho frío"),
        (["calor", "tengo calor", "hace calor", "me sofoco"], "Tengo mucho calor"),
        (["baño", "necesito ir al baño", "quiero ir al baño", "llévame al baño"], "Necesito ir al baño"),
        (["cansado", "cansada", "estoy cansado", "estoy cansada", "quiero descansar", "quiero dormir", "tengo sueño"], "Estoy muy cansado/a"),
        (["solo", "sola", "me siento solo", "me siento sola", "estoy solo", "estoy sola"], "Me siento solo/a, necesito compañía")
    ]

    /// Palabras de respuesta simple
    private let yesKeywords = [
        "sí", "bien", "ok", "bueno", "está bien", "estoy bien",
        "de acuerdo", "vale", "claro", "correcto", "perfecto",
        "todo bien", "me siento bien"
    ]
    private let noKeywords = [
        "no", "nada", "no quiero", "no gracias", "tampoco"
    ]

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

        // 3. Respuestas simples
        //    Para "yes": acepta frases completas como "estoy bien", "me siento bien"
        //    Para "no": solo frases cortas para evitar falsos positivos
        for keyword in yesKeywords {
            if text == keyword || text.hasSuffix(" \(keyword)") || text.hasPrefix("\(keyword) ") {
                return .yes
            }
        }

        let wordCount = text.split(separator: " ").count
        if wordCount <= 3 {
            for keyword in noKeywords {
                if text == keyword || text.hasSuffix(" \(keyword)") {
                    return .no
                }
            }
        }

        return nil
    }
}
