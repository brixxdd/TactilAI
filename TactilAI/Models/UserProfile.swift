// UserProfile.swift
// TactilAI
//
// Modelo que almacena el perfil del usuario, incluyendo su nombre,
// rol (cuidador o paciente) y preferencias de accesibilidad.

import Foundation

/// Perfil del usuario con sus preferencias de accesibilidad
struct UserProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var role: UserRole
    
    init(id: UUID = UUID(), name: String, role: UserRole = .caregiver) {
        self.id = id
        self.name = name
        self.role = role
    }
}

/// Roles disponibles dentro de la aplicación
enum UserRole: String, Codable {
    case caregiver = "cuidador"
    case patient = "paciente"
}
