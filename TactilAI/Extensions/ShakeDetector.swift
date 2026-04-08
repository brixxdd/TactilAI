// ShakeDetector.swift
// TactilAI
//
// Detecta el gesto de agitar el iPhone (shake).
// Julia puede agitar el teléfono para activar comandos de voz
// sin necesidad de encontrar ningún botón en pantalla.

import SwiftUI

// MARK: - Notificación de shake

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

// MARK: - Interceptar shake en UIWindow

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

// MARK: - Modificador SwiftUI para shake

struct OnShakeModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

extension View {
    /// Ejecuta una acción cuando el usuario agita el teléfono.
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(OnShakeModifier(action: action))
    }
}
