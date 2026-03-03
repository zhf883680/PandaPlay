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
    @State private var isLaunching: Bool = true

    var body: some View {
        Group {
            if isLaunching {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载中...")
                        .foregroundColor(.secondary)
                }
            } else {
                HomeView()
            }
        }
        .task {
            await autoLoginIfNeeded()
            await MainActor.run {
                isLaunching = false
            }
        }
    }

    private func autoLoginIfNeeded() async {
        guard !authManager.isAuthenticated,
              let server = serverManager.currentServer else {
            return
        }

        // Try to auto-login with saved credentials
        _ = await authManager.tryAutoLogin(
            serverURL: server.url,
            serverId: server.id
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(ServerManager())
        .environmentObject(AuthManager())
        .environmentObject(ErrorManager.shared)
        .environmentObject(ToastManager.shared)
}
