// EmergencyService.swift
// TactilAI
//
// Servicio de emergencia que gestiona el contacto de emergencia,
// llamadas telefónicas y envío de SMS predefinidos.
// Usa URL schemes nativos de iOS (tel: y sms:).

import SwiftUI

@Observable
final class EmergencyService {

    // MARK: - Contacto de emergencia (persistido con UserDefaults)

    var contactName: String {
        get { UserDefaults.standard.string(forKey: "emergencyContactName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "emergencyContactName") }
    }

    var contactPhone: String {
        get { UserDefaults.standard.string(forKey: "emergencyContactPhone") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "emergencyContactPhone") }
    }

    var hasContact: Bool { !contactPhone.isEmpty }

    // MARK: - Cooldown para evitar disparos accidentales

    private var lastTriggerDate: Date?
    private let cooldownInterval: TimeInterval = 10

    var canTrigger: Bool {
        guard let last = lastTriggerDate else { return true }
        return Date().timeIntervalSince(last) >= cooldownInterval
    }

    var cooldownRemaining: TimeInterval {
        guard let last = lastTriggerDate else { return 0 }
        let elapsed = Date().timeIntervalSince(last)
        return max(0, cooldownInterval - elapsed)
    }

    // MARK: - Mensajes de malestar predefinidos

    static let distressMessages: [(message: String, icon: String, color: String)] = [
        ("Me duele mucho la cabeza", "brain.head.profile", "FF9500"),
        ("No puedo respirar bien", "lungs.fill", "FF453A"),
        ("Me siento muy mal", "heart.slash.fill", "FF6B6B"),
        ("Necesito mi medicina", "pills.fill", "7B6EF6")
    ]

    // MARK: - Llamar al contacto de emergencia

    func callEmergencyContact() {
        guard hasContact, canTrigger else { return }
        let cleaned = contactPhone.replacingOccurrences(
            of: "[^0-9+]", with: "", options: .regularExpression
        )
        guard let url = URL(string: "tel://\(cleaned)") else { return }
        lastTriggerDate = Date()
        UIApplication.shared.open(url)
    }

    // MARK: - Enviar SMS con mensaje predefinido

    func sendSMS(message: String) {
        guard hasContact else { return }
        let cleaned = contactPhone.replacingOccurrences(
            of: "[^0-9+]", with: "", options: .regularExpression
        )
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? message
        guard let url = URL(string: "sms:\(cleaned)&body=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - SOS completo: llamada + SMS

    func triggerSOS() {
        guard hasContact, canTrigger else { return }
        lastTriggerDate = Date()
        HapticEngine.shared.play(word: "Pánico")

        // Enviar SMS primero, luego llamar
        let sosMessage = "🚨 EMERGENCIA: \(contactName.isEmpty ? "Tu contacto" : contactName) necesita ayuda urgente. Enviado desde TactilAI."
        sendSMS(message: sosMessage)

        // Pequeño delay para que el SMS se abra primero
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            callEmergencyContact()
        }
    }

    // MARK: - Enviar mensaje de malestar

    func sendDistressMessage(_ message: String) {
        guard hasContact else { return }
        let fullMessage = "⚠️ \(message). — Enviado desde TactilAI por \(contactName.isEmpty ? "usuario" : contactName)"
        sendSMS(message: fullMessage)
    }
}
