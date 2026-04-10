// AppState.swift
// TactilAI
//
// Estado global de la aplicación para coordinar navegación y comandos de voz
// entre las diferentes vistas.

import Foundation
import Observation

enum TabDestination: Int, CaseIterable {
    case home = 0      // CaregiverView
    case patterns = 1  // JuliaView  
    case emergency = 2 // EmergencyView

    var name: String {
        switch self {
        case .home: return "Inicio"
        case .patterns: return "Patrones"
        case .emergency: return "Emergencia"
        }
    }
}

@Observable
final class AppState {
    static let shared = AppState()

    var selectedTab: TabDestination = .patterns
    var isVoiceNavigationMode: Bool = false
    var lastVoiceCommand: String = ""
    var voiceNavigationFeedback: String?

    private init() {}

    func navigateTo(_ tab: TabDestination) {
        selectedTab = tab
        HapticEngine.shared.playPattern(for: tab)
    }

    func showVoiceFeedback(_ message: String) {
        voiceNavigationFeedback = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.voiceNavigationFeedback = nil
        }
    }
}
