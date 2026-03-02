//
//  ContentView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if serverManager.hasConfiguredServer {
                if authManager.isAuthenticated {
                    HomeView()
                } else {
                    LoginView()
                }
            } else {
                ServerSetupView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ServerManager())
        .environmentObject(AuthManager())
        .environmentObject(ErrorManager.shared)
        .environmentObject(ToastManager.shared)
}
