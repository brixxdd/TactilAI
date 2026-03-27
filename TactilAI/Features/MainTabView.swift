// MainTabView.swift
// TactilAI
//
// TabView principal con las 3 pestañas de la app.

import SwiftUI

struct MainTabView: View {

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(
            red: 7/255, green: 7/255, blue: 26/255, alpha: 0.95)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            CaregiverView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Inicio")
                }

            JuliaView()
                .tabItem {
                    Image(systemName: "waveform")
                    Text("Patrones")
                }

            EmergencyView()
                .tabItem {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Emergencia")
                }
        }
        .tint(Color(hex: "7B6EF6"))
    }
}

#Preview {
    MainTabView()
}
