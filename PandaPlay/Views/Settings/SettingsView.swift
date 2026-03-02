//
//  SettingsView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager

    var body: some View {
        NavigationView {
            List {
                // Server Section
                Section {
                    if let server = serverManager.currentServer {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(server.name)
                                    .font(.headline)
                                Text(server.url)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }

                    NavigationLink("管理服务器") {
                        ServerManagerView()
                    }
                } header: {
                    Text("服务器")
                }

                // User Section
                Section {
                    if let user = authManager.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }

                    Button("退出登录") {
                        if let serverId = serverManager.currentServer?.id {
                            authManager.logout(serverId: serverId)
                        }
                    }
                } header: {
                    Text("用户")
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
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.blue)
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
}
