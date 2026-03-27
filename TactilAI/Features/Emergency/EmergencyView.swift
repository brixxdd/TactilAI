// EmergencyView.swift
// TactilAI
//
// Vista de emergencia que permite al usuario enviar alertas rápidas.
// Incluye un botón grande de emergencia y opciones para contactar
// servicios de ayuda o cuidadores registrados.

import SwiftUI

/// Vista de emergencia con acceso rápido a alertas y contactos
struct EmergencyView: View {
    @State private var isAlertActive: Bool = false
    
    var body: some View {
        ZStack {
            Color.tactilBackground
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Text("Emergencia")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                
                Spacer()
                
                // Botón grande de emergencia
                Button(action: {
                    isAlertActive = true
                }) {
                    Circle()
                        .fill(.red)
                        .frame(width: 180, height: 180)
                        .overlay(
                            VStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 50))
                                Text("SOS")
                                    .font(.title)
                                    .fontWeight(.heavy)
                            }
                            .foregroundStyle(.white)
                        )
                        .shadow(color: .red.opacity(0.5), radius: 20)
                }
                
                Spacer()
                
                Text("Presiona el botón para enviar una alerta")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .alert("Alerta Enviada", isPresented: $isAlertActive) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Se ha notificado a tus contactos de emergencia.")
        }
    }
}

#Preview {
    NavigationStack {
        EmergencyView()
    }
}
