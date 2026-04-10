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
    case sos
    case distress(String)
    case yes
    case no
    case navigate(TabDestination)
    case action(VoiceAction)
    
    static func == (lhs: VoiceCommand, rhs: VoiceCommand) -> Bool {
        switch (lhs, rhs) {
        case (.sos, .sos): return true
        case (.distress(let a), .distress(let b)): return a == b
        case (.yes, .yes): return true
        case (.no, .no): return true
        case (.navigate(let a), .navigate(let b)): return a == b
        case (.action(let a), .action(let b)): return a == b
        default: return false
        }
    }
}

/// Acciones de voz disponibles
enum VoiceAction: String, CaseIterable {
    case sendMessage
    case triggerSOS
    case call
    case sendSMS
    case playPattern
    case help
    
    var description: String {
        switch self {
        case .sendMessage: return "Enviar mensaje"
        case .triggerSOS: return "Activar SOS"
        case .call: return "Hacer llamada"
        case .sendSMS: return "Enviar SMS"
        case .playPattern: return "Reproducir patrón"
        case .help: return "Mostrar ayuda"
        }
    }
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

    // MARK: - Comandos de navegación

    private let navigateHomeKeywords = [
        "ve a inicio", "ve al inicio", "ir a inicio", "ir al inicio",
        "inicio", "pestaña inicio", "home", "volver al inicio",
        "vámonos a inicio", "ve a casa", "regresa al inicio"
    ]

    private let navigatePatternsKeywords = [
        "ve a patrones", "ve a patrón", "ir a patrones", "ir a patrón",
        "patrones", "pestaña patrones", "modo julia", "vista julia",
        "zonas táctiles", "vámonos a patrones", "patrón", "zonas"
    ]

    private let navigateEmergencyKeywords = [
        "ve a emergencia", "ir a emergencia",
        "pestaña emergencia", "emergencias",
        "vámonos a emergencia", "modo emergencia", "pantalla emergencia",
        "muestra emergencia", "abre emergencia"
    ]

    // MARK: - Comandos de acción

    private let actionSOSKeywords = [
        "haz emergencia", "activar emergencia", "botón rojo",
        "sos", "llamar emergencia", "emergencia ahora",
        "activar sos", "pánico", "ayuda urgente ahora"
    ]

    private let actionCallKeywords = [
        "haz llamada", "llama", "llamar", "telefonear",
        "comunicar", "comunícame", "llámame"
    ]

    private let actionSendMessageKeywords = [
        "envía mensaje", "enviar mensaje", "mandar mensaje",
        "manda mensaje", "escribe", "escribir mensaje"
    ]

    private let actionSendSMSKeywords = [
        "envía sms", "enviar sms", "mandar sms", "manda sms",
        "mensaje de texto", "texto"
    ]

    private let actionPlayPatternKeywords = [
        "reproduce", "reproducir", "tocar", "tocar patrón",
        "muestra el patrón", "cómo se siente", "ver patrón"
    ]

    private let actionHelpKeywords = [
        "qué puedes hacer", "comandos", "lista de comandos",
        "dime los comandos", "qué hago", "cómo uso esto"
    ]

    // MARK: - Detectar comando en texto

    func detectCommand(in transcript: String) -> VoiceCommand? {
        let text = transcript.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return nil }

        if let nav = detectNavigation(in: text) {
            return .navigate(nav)
        }

        if let action = detectAction(in: text) {
            return .action(action)
        }

        if let sos = detectSOS(in: text) {
            return sos
        }

        if let distress = detectDistress(in: text) {
            return distress
        }

        if let yesNo = detectYesNo(in: text) {
            return yesNo
        }

        return nil
    }

    private func detectNavigation(in text: String) -> TabDestination? {
        for keyword in navigateHomeKeywords {
            if text.contains(keyword) {
                return .home
            }
        }

        for keyword in navigatePatternsKeywords {
            if text.contains(keyword) {
                return .patterns
            }
        }

        for keyword in navigateEmergencyKeywords {
            if text.contains(keyword) {
                return .emergency
            }
        }

        return nil
    }

    private func detectAction(in text: String) -> VoiceAction? {
        for keyword in actionSOSKeywords {
            if text.contains(keyword) {
                return .triggerSOS
            }
        }

        for keyword in actionCallKeywords {
            if text.contains(keyword) {
                return .call
            }
        }

        for keyword in actionSendMessageKeywords {
            if text.contains(keyword) {
                return .sendMessage
            }
        }

        for keyword in actionSendSMSKeywords {
            if text.contains(keyword) {
                return .sendSMS
            }
        }

        for keyword in actionPlayPatternKeywords {
            if text.contains(keyword) {
                return .playPattern
            }
        }

        for keyword in actionHelpKeywords {
            if text.contains(keyword) {
                return .help
            }
        }

        return nil
    }

    private func detectSOS(in text: String) -> VoiceCommand? {
        for keyword in sosKeywords {
            if text.contains(keyword) {
                return .sos
            }
        }
        return nil
    }

    private func detectDistress(in text: String) -> VoiceCommand? {
        for pattern in distressPatterns {
            for keyword in pattern.keywords {
                if text.contains(keyword) {
                    return .distress(pattern.message)
                }
            }
        }
        return nil
    }

    private func detectYesNo(in text: String) -> VoiceCommand? {
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

    func getAvailableCommands() -> [String] {
        return [
            "Navegación: 've a inicio', 've a patrones', 've a emergencia'",
            "Emergencia: 'emergencia', 'socorro', 'ayuda'",
            "Malestar: 'me duele la cabeza', 'no puedo respirar'",
            "Respuestas: 'sí', 'no', 'bien', 'mal'",
            "Acciones: 'haz emergencia', 'haz llamada', 'ayuda'"
        ]
    }
}
