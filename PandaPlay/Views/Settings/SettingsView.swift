//
//  SettingsView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager

    @State private var serverInfo: ServerInfo?
    @State private var videoQuality: VideoQuality = UserDefaultsManager.shared.videoQuality

    var body: some View {
        NavigationView {
            List {
                // Playback Section
                Section {
                    Picker("视频质量", selection: $videoQuality) {
                        ForEach(VideoQuality.allCases, id: \.rawValue) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .onChange(of: videoQuality) { newValue in
                        UserDefaultsManager.shared.videoQuality = newValue
                    }

                    Text("选择「自动」将优先直连播放，不转码")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("播放")
                }

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
                        Text("PandaPlay")
                        Spacer()
                        AppLogoView(size: DeviceType.current == .iPhone ? 20 : 24)
                    }

                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    if let info = serverInfo {
                        if let name = info.serverName {
                            HStack {
                                Text("服务器")
                                Spacer()
                                Text(name)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        if let version = info.version {
                            HStack {
                                Text("服务器版本")
                                Spacer()
                                Text(version)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let os = info.operatingSystem {
                            HStack {
                                Text("系统")
                                Spacer()
                                Text(os)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if let userName = authManager.currentUser?.name {
                        HStack {
                            Text("当前用户")
                            Spacer()
                            Text(userName)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
        }
        .task {
            await loadServerInfo()
        }
    }

    private func loadServerInfo() async {
        guard let serverURL = serverManager.currentServer?.url,
              let accessToken = authManager.accessToken else { return }
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        serverInfo = (try? await client.getServerInfo())
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(ServerManager())
        .environmentObject(ToastManager.shared)
}
