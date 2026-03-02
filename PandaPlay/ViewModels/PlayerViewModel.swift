//
//  PlayerViewModel.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation
import SwiftUI
import Combine
import KSPlayer

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var playerResource: KSPlayerResource?

    private var client: EmbyClient?
    private var userId: String?

    func loadPlayer(for mediaItem: MediaItem, serverURL: String, userId: String, accessToken: String) async {
        isLoading = true
        errorMessage = nil

        client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        self.userId = userId

        // Get stream URL - use direct stream URL for KSPlayer (supports MKV)
        guard let streamURL = client?.getStreamURL(itemId: mediaItem.id, userId: userId, isStatic: false) else {
            errorMessage = "无法获取播放地址"
            isLoading = false
            return
        }

        print("🎬 [PlayerViewModel] Stream URL: \(streamURL.absoluteString)")

        // 设置 KSPlayer 选项
        let options = KSOptions()
        // 使用 avOptions 设置 HTTP 认证头
        options.avOptions = [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "X-Emby-Token": accessToken,
                "Accept": "*/*"
            ]
        ]
        // KSOptions 的 isAutoPlay 是静态属性，需要用类名访问
        KSOptions.isAutoPlay = true
        options.isAccurateSeek = true

        // 创建资源定义
        let definition = KSPlayerResourceDefinition(
            url: streamURL,
            definition: "原画",
            options: options
        )

        // 创建播放资源
        let resource = KSPlayerResource(
            name: mediaItem.name ?? "Video",
            definitions: [definition]
        )

        playerResource = resource
        isLoading = false
    }

    func cleanup() {
        playerResource = nil
    }

    func reportPlaybackStart(itemId: String, userId: String) async {
        print("🎬 [PlayerViewModel] Report playback start for item: \(itemId)")
    }

    func reportPlaybackProgress(itemId: String, positionTicks: Int64, userId: String) async {
        print("🎬 [PlayerViewModel] Report playback progress: \(positionTicks) ticks")
    }

    func reportPlaybackStopped(itemId: String, positionTicks: Int64, userId: String) async {
        print("🎬 [PlayerViewModel] Report playback stopped at: \(positionTicks) ticks")
    }
}
