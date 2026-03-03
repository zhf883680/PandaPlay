//
//  SettingsView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var serverManager: ServerManager

    var body: some View {
        NavigationView {
            List {
                // Server Section
                Section {
                    NavigationLink("服务器管理") {
                        ServerManagerView()
                    }
                } header: {
                    Text("服务器")
                }

                // About Section
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("PandaPlay")
                        Spacer()
                        AppLogoView(size: DeviceType.current == .iPhone ? 20 : 24)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(ServerManager())
        .environmentObject(ToastManager.shared)
}
