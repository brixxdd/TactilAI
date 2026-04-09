// EmergencyView.swift
// TactilAI
//
// Vista de emergencia completa con:
// - Configuración de contacto de emergencia
// - Botón SOS que llama + envía SMS
// - Mensajes de malestar predefinidos (dolor de cabeza, no puedo respirar, etc.)
// Estilo Liquid Glass manual.

import SwiftUI

struct EmergencyView: View {

    @State private var emergencyService = EmergencyService()
    @State private var glowPhase = false
    @State private var sosPressed = false
    @State private var sentMessage: String?
    @State private var showContactEditor = false
    @State private var editingName = ""
    @State private var editingPhone = ""
    @State private var cooldownTimer: Timer?
    @State private var cooldownDisplay: Int = 0

    var body: some View {
        ZStack {
            // Fondo base
            Color(hex: "07071A")
                .ignoresSafeArea()

            // Ambient orbs
            Circle()
                .fill(Color(hex: "FF453A").opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -60, y: -180)

            Circle()
                .fill(Color(hex: "FF9500").opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 120, y: 300)

            Circle()
                .fill(Color(hex: "7B6EF6").opacity(0.06))
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .offset(x: -100, y: 400)

            // Contenido
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    headerSection
                        .padding(.top, 16)

                    contactCard

                    sosButton

                    distressMessagesSection

                    infoFooter
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            // Overlay de confirmación de envío
            if let message = sentMessage {
                sentOverlay(message: message)
            }
        }
        .fontDesign(.rounded)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
        .sheet(isPresented: $showContactEditor) {
            contactEditorSheet
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "FF453A").opacity(0.4), Color(hex: "FF453A").opacity(0.0)],
                            center: .center, startRadius: 10, endRadius: 35
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(glowPhase ? 1.15 : 1.0)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FF453A"), Color(hex: "FF6B6B")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Emergencia")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 5) {
                    Circle()
                        .fill(emergencyService.hasContact ? Color(hex: "4ECDC4") : Color(hex: "FF9500"))
                        .frame(width: 7, height: 7)
                        .scaleEffect(glowPhase ? 1.3 : 0.8)

                    Text(emergencyService.hasContact ? "Contacto configurado" : "Sin contacto")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Contact Card

    private var contactCard: some View {
        Button {
            editingName = emergencyService.contactName
            editingPhone = emergencyService.contactPhone
            showContactEditor = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF453A").opacity(0.3), Color(hex: "FF9500").opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: emergencyService.hasContact ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: emergencyService.hasContact ? "4ECDC4" : "FF9500"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if emergencyService.hasContact {
                        Text(emergencyService.contactName.isEmpty ? "Contacto" : emergencyService.contactName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(emergencyService.contactPhone)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text("Agregar contacto de emergencia")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "FF9500"))

                        Text("Toca para configurar")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - SOS Button

    private var sosButton: some View {
        VStack(spacing: 16) {
            Button {
                triggerSOS()
            } label: {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "FF453A").opacity(0.3), .clear],
                                center: .center, startRadius: 30, endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(glowPhase ? 1.1 : 0.95)

                    // Main circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF453A"), Color(hex: "FF2D55")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 150, height: 150)
                        .shadow(color: Color(hex: "FF453A").opacity(0.5), radius: 20)

                    // Glass overlay
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.0)],
                                startPoint: .top, endPoint: .center
                            )
                        )
                        .frame(width: 150, height: 150)

                    // Border
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color(hex: "FF453A").opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 150, height: 150)

                    // Content
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40, weight: .bold))
                        Text("SOS")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .disabled(!emergencyService.hasContact || !emergencyService.canTrigger)
            .opacity(emergencyService.hasContact ? 1.0 : 0.4)
            .scaleEffect(sosPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3), value: sosPressed)

            // Cooldown indicator
            if cooldownDisplay > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                    Text("Espera \(cooldownDisplay)s")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "FF9500"))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(hex: "FF9500").opacity(0.12))
                .clipShape(Capsule())
            } else if !emergencyService.hasContact {
                Text("Configura un contacto para activar SOS")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                Text("Llamada directa de emergencia")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Distress Messages

    private var distressMessagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sección de llamadas
            HStack(spacing: 6) {
                Image(systemName: "phone.arrow.up.right.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "FF9500"))
                Text("Llamada de malestar")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text("Llama directamente a tu contacto")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))

            VStack(spacing: 10) {
                ForEach(EmergencyService.distressMessages.prefix(2), id: \.message) { item in
                    distressCallButton(message: item.message, icon: item.icon, colorHex: item.color)
                }
            }

            // Sección de SMS
            HStack(spacing: 6) {
                Image(systemName: "message.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "7B6EF6"))
                Text("Mensaje de malestar")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 8)

            Text("Envía un SMS a tu contacto")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))

            VStack(spacing: 10) {
                ForEach(EmergencyService.distressMessages.suffix(2), id: \.message) { item in
                    distressSMSButton(message: item.message, icon: item.icon, colorHex: item.color)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func distressCallButton(message: String, icon: String, colorHex: String) -> some View {
        let color = Color(hex: colorHex)
        return Button {
            sendDistressCall(message: message)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(color)
                }

                Text(message)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "phone.arrow.up.right.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(color.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCardAccent(cornerRadius: 16, color: color)
        }
        .buttonStyle(.plain)
        .disabled(!emergencyService.hasContact)
        .opacity(emergencyService.hasContact ? 1.0 : 0.4)
    }

    private func distressSMSButton(message: String, icon: String, colorHex: String) -> some View {
        let color = Color(hex: colorHex)
        return Button {
            sendDistressSMS(message: message)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(color)
                }

                Text(message)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "message.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(color.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCardAccent(cornerRadius: 16, color: color)
        }
        .buttonStyle(.plain)
        .disabled(!emergencyService.hasContact)
        .opacity(emergencyService.hasContact ? 1.0 : 0.4)
    }

    // MARK: - Info Footer

    private var infoFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
            Text("Todas las emergencias inician una llamada directa al contacto")
                .font(.system(size: 11))
        }
        .foregroundStyle(.white.opacity(0.25))
        .padding(.top, 4)
    }

    // MARK: - Sent Overlay

    private func sentOverlay(message: String) -> some View {
        ZStack {
            Color(hex: "4ECDC4").opacity(0.2)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Color(hex: "4ECDC4"))
                    .shadow(color: Color(hex: "4ECDC4").opacity(0.5), radius: 16)

                Text(message)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .glassCard()
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    // MARK: - Contact Editor Sheet

    private var contactEditorSheet: some View {
        ZStack {
            Color(hex: "07071A")
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Contacto de Emergencia")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        showContactEditor = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))

                    TextField("Nombre del contacto", text: $editingName)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                }

                // Phone field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Teléfono")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))

                    TextField("Número de teléfono", text: $editingPhone)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .keyboardType(.phonePad)
                        .padding(14)
                        .glassCard(cornerRadius: 14)
                }

                Spacer()

                // Save button
                Button {
                    emergencyService.contactName = editingName
                    emergencyService.contactPhone = editingPhone
                    showContactEditor = false
                } label: {
                    Text("Guardar contacto")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "7B6EF6"), Color(hex: "4ECDC4")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "7B6EF6").opacity(0.4), radius: 12)
                }
                .disabled(editingPhone.isEmpty)
                .opacity(editingPhone.isEmpty ? 0.4 : 1.0)

                // Delete contact
                if emergencyService.hasContact {
                    Button {
                        emergencyService.contactName = ""
                        emergencyService.contactPhone = ""
                        editingName = ""
                        editingPhone = ""
                        showContactEditor = false
                    } label: {
                        Text("Eliminar contacto")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "FF453A"))
                    }
                }
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func triggerSOS() {
        sosPressed = true
        emergencyService.triggerSOS()

        withAnimation(.easeIn(duration: 0.15)) {
            sentMessage = "Llamando al contacto..."
        }

        startCooldown()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { sentMessage = nil }
            sosPressed = false
        }
    }

    private func sendDistressCall(message: String) {
        emergencyService.sendDistressMessage(message)

        withAnimation(.easeIn(duration: 0.15)) {
            sentMessage = "Llamando al contacto..."
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { sentMessage = nil }
        }
    }

    private func sendDistressSMS(message: String) {
        emergencyService.sendDistressSMS(message)

        withAnimation(.easeIn(duration: 0.15)) {
            sentMessage = "Abriendo mensaje..."
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { sentMessage = nil }
        }
    }

    private func startCooldown() {
        cooldownDisplay = 10
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if cooldownDisplay > 0 {
                cooldownDisplay -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    EmergencyView()
}
