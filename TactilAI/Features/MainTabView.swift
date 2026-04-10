// MainTabView.swift
// TactilAI
//
// TabView principal con las 3 pestañas de la app.
// Soporta navegación programática via AppState para comandos de voz.

import SwiftUI

struct MainTabView: View {
    @State private var appState = AppState.shared

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(
            red: 7/255, green: 7/255, blue: 26/255, alpha: 0.95)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            CaregiverView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Inicio")
                }
                .tag(TabDestination.home)

            JuliaView()
                .tabItem {
                    Image(systemName: "waveform")
                    Text("Patrones")
                }
                .tag(TabDestination.patterns)

            EmergencyView()
                .tabItem {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Emergencia")
                }
                .tag(TabDestination.emergency)
        }
        .tint(Color(hex: "7B6EF6"))
        .onChange(of: appState.selectedTab) { oldValue, newValue in
            HapticEngine.shared.playPattern(for: newValue)
        }
    }
}

#Preview {
    MainTabView()
}
