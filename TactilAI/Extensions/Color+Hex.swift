// Color+Hex.swift
// TactilAI
//
// Extensión de Color para crear colores a partir de códigos hexadecimales.
// Incluye los colores personalizados de la paleta de TactilAI.

import SwiftUI

extension Color {
    /// Crea un Color a partir de un código hexadecimal (ej: "07071A")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - Colores de la paleta TactilAI
    
    /// Color de fondo principal oscuro (#07071A)
    static let tactilBackground = Color(hex: "07071A")
    
    /// Verde menta para estados activos y conexión (#4ECDC4)
    static let tactilGreen = Color(hex: "4ECDC4")
    
    /// Púrpura principal para acciones y acentos (#7B6EF6)
    static let tactilPurple = Color(hex: "7B6EF6")
    
    /// Rojo de emergencia (#FF453A)
    static let tactilRed = Color(hex: "FF453A")
    
    /// Blanco con opacidad para bordes glass
    static let glassStroke = Color.white.opacity(0.12)
    
    /// Fondo de tarjetas glass
    static let glassFill = Color.white.opacity(0.08)
}
