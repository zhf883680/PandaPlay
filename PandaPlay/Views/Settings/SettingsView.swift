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
    @State private var seekStep: Int = UserDefaultsManager.shared.seekStep
    @State private var danmakuEnabled: Bool = UserDefaultsManager.shared.danmakuEnabled
    @State private var danmakuOpacity: Double = UserDefaultsManager.shared.danmakuOpacity
    @State private var danmakuFontScale: Double = UserDefaultsManager.shared.danmakuFontScale
    @State private var danmakuSpeedScale: Double = UserDefaultsManager.shared.danmakuSpeedScale
    @State private var danmakuDensity: Int = UserDefaultsManager.shared.danmakuDensity
    @State private var danmakuAreaPercent: Double = UserDefaultsManager.shared.danmakuAreaPercent
    @State private var danmakuHideScroll: Bool = UserDefaultsManager.shared.danmakuHideScroll
    @State private var danmakuHideTop: Bool = UserDefaultsManager.shared.danmakuHideTop
    @State private var danmakuHideBottom: Bool = UserDefaultsManager.shared.danmakuHideBottom
    @State private var danmakuOffsetMs: Int = UserDefaultsManager.shared.danmakuOffsetMs
    @State private var danmakuAutoLoad: Bool = UserDefaultsManager.shared.danmakuAutoLoad
    @State private var danmakuAutoMatch: Bool = UserDefaultsManager.shared.danmakuAutoMatch

    var body: some View {
        #if os(tvOS)
        tvOSBody
        #else
        iOSBody
        #endif
    }

    // MARK: - tvOS

    #if os(tvOS)
    private var tvOSBody: some View {
        List {
            playerSection
            danmakuSection
            serverSection
            aboutSection
        }
        .navigationTitle("设置")
        .task { await loadServerInfo() }
    }
    #endif

    // MARK: - iOS

    private var iOSBody: some View {
        NavigationView {
            List {
                playerSection
                danmakuSection
                serverSection
                aboutSection
            }
            .navigationTitle("设置")
        }
        .task { await loadServerInfo() }
    }

    // MARK: - Sections

    private var playerSection: some View {
        Section {
            Picker("视频质量", selection: $videoQuality) {
                ForEach(VideoQuality.allCases, id: \.rawValue) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            .onChange(of: videoQuality) { _, newValue in
                UserDefaultsManager.shared.videoQuality = newValue
            }

            Picker("快进步长", selection: $seekStep) {
                ForEach([5, 10, 15, 30], id: \.self) { step in
                    Text("\(step) 秒").tag(step)
                }
            }
            .onChange(of: seekStep) { _, newValue in
                UserDefaultsManager.shared.seekStep = newValue
            }

            Text("选择「自动」将优先直连播放，不转码")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("播放")
        }
    }

    private var danmakuSection: some View {
        Section {
            Toggle("启用弹幕", isOn: $danmakuEnabled)
                .onChange(of: danmakuEnabled) { _, newValue in
                    UserDefaultsManager.shared.danmakuEnabled = newValue
                }

            if danmakuEnabled {
                danmakuDetailSettings
            }
        } header: {
            Text("弹幕")
        }
    }

    private var danmakuDetailSettings: some View {
        Group {
            Toggle("自动加载", isOn: $danmakuAutoLoad)
                .onChange(of: danmakuAutoLoad) { _, newValue in
                    UserDefaultsManager.shared.danmakuAutoLoad = newValue
                }

            Toggle("自动匹配", isOn: $danmakuAutoMatch)
                .onChange(of: danmakuAutoMatch) { _, newValue in
                    UserDefaultsManager.shared.danmakuAutoMatch = newValue
                }

            #if os(tvOS)
            Picker("不透明度", selection: $danmakuOpacity) {
                ForEach(stride(from: 0.1, through: 1.0, by: 0.1).map { $0 }, id: \.self) { val in
                    Text("\(Int(val * 100))%").tag(val)
                }
            }
            .onChange(of: danmakuOpacity) { _, newValue in
                UserDefaultsManager.shared.danmakuOpacity = newValue
            }

            Picker("字体大小", selection: $danmakuFontScale) {
                ForEach(stride(from: 0.5, through: 2.0, by: 0.1).map { $0 }, id: \.self) { val in
                    Text(String(format: "%.1fx", val)).tag(val)
                }
            }
            .onChange(of: danmakuFontScale) { _, newValue in
                UserDefaultsManager.shared.danmakuFontScale = newValue
            }

            Picker("弹幕速度", selection: $danmakuSpeedScale) {
                ForEach(stride(from: 0.5, through: 2.0, by: 0.1).map { $0 }, id: \.self) { val in
                    Text(String(format: "%.1fx", val)).tag(val)
                }
            }
            .onChange(of: danmakuSpeedScale) { _, newValue in
                UserDefaultsManager.shared.danmakuSpeedScale = newValue
            }

            Picker("显示区域", selection: $danmakuAreaPercent) {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { val in
                    Text("\(Int(val * 100))%").tag(val)
                }
            }
            .onChange(of: danmakuAreaPercent) { _, newValue in
                UserDefaultsManager.shared.danmakuAreaPercent = newValue
            }
            #else
            HStack {
                Text("不透明度")
                Spacer()
                Text("\(Int(danmakuOpacity * 100))%")
                    .foregroundColor(.secondary)
            }
            Slider(value: $danmakuOpacity, in: 0.1...1.0, step: 0.1)
                .onChange(of: danmakuOpacity) { _, newValue in
                    UserDefaultsManager.shared.danmakuOpacity = newValue
                }

            HStack {
                Text("字体大小")
                Spacer()
                Text(String(format: "%.1fx", danmakuFontScale))
                    .foregroundColor(.secondary)
            }
            Slider(value: $danmakuFontScale, in: 0.5...2.0, step: 0.1)
                .onChange(of: danmakuFontScale) { _, newValue in
                    UserDefaultsManager.shared.danmakuFontScale = newValue
                }

            HStack {
                Text("弹幕速度")
                Spacer()
                Text(String(format: "%.1fx", danmakuSpeedScale))
                    .foregroundColor(.secondary)
            }
            Slider(value: $danmakuSpeedScale, in: 0.5...2.0, step: 0.1)
                .onChange(of: danmakuSpeedScale) { _, newValue in
                    UserDefaultsManager.shared.danmakuSpeedScale = newValue
                }

            HStack {
                Text("显示区域")
                Spacer()
                Text("\(Int(danmakuAreaPercent * 100))%")
                    .foregroundColor(.secondary)
            }
            Slider(value: $danmakuAreaPercent, in: 0.25...1.0, step: 0.25)
                .onChange(of: danmakuAreaPercent) { _, newValue in
                    UserDefaultsManager.shared.danmakuAreaPercent = newValue
                }
            #endif

            Picker("弹幕密度", selection: $danmakuDensity) {
                Text("不限").tag(0)
                ForEach([10, 20, 30, 50], id: \.self) { count in
                    Text("\(count) 条").tag(count)
                }
            }
            .onChange(of: danmakuDensity) { _, newValue in
                UserDefaultsManager.shared.danmakuDensity = newValue
            }

            Toggle("隐藏滚动弹幕", isOn: $danmakuHideScroll)
                .onChange(of: danmakuHideScroll) { _, newValue in
                    UserDefaultsManager.shared.danmakuHideScroll = newValue
                }

            Toggle("隐藏顶部弹幕", isOn: $danmakuHideTop)
                .onChange(of: danmakuHideTop) { _, newValue in
                    UserDefaultsManager.shared.danmakuHideTop = newValue
                }

            Toggle("隐藏底部弹幕", isOn: $danmakuHideBottom)
                .onChange(of: danmakuHideBottom) { _, newValue in
                    UserDefaultsManager.shared.danmakuHideBottom = newValue
                }
        }
    }

    private var serverSection: some View {
        Section {
            NavigationLink("服务器管理") {
                ServerManagerView()
            }
        } header: {
            Text("服务器")
        }
    }

    private var aboutSection: some View {
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
