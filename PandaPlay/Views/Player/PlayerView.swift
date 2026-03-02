//
//  PlayerView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI
import KSPlayer

struct PlayerView: View {
    let mediaItem: MediaItem
    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let resource = viewModel.playerResource {
                // KSVideoPlayerView 是 SwiftUI View，直接使用 URL 和 options
                if let definition = resource.definitions.first {
                    KSVideoPlayerView(url: definition.url, options: definition.options)
                        .onDisappear {
                            viewModel.cleanup()
                        }
                }
            } else if viewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.white)
                    Text("加载中...")
                        .foregroundColor(.white)
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.white)
                    Button("重试") {
                        Task {
                            if let serverURL = serverManager.currentServer?.url,
                               let userId = authManager.userId,
                               let accessToken = authManager.accessToken {
                                await viewModel.loadPlayer(
                                    for: mediaItem,
                                    serverURL: serverURL,
                                    userId: userId,
                                    accessToken: accessToken
                                )
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("返回") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .task {
            if let serverURL = serverManager.currentServer?.url,
               let userId = authManager.userId,
               let accessToken = authManager.accessToken {
                await viewModel.loadPlayer(
                    for: mediaItem,
                    serverURL: serverURL,
                    userId: userId,
                    accessToken: accessToken
                )
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    PlayerView(mediaItem: MediaItem(
        id: "1",
        name: "示例电影",
        type: "Movie",
        overview: "示例描述",
        imageTags: nil,
        imageBlurHashes: nil,
        productionYear: 2024,
        genres: nil,
        runTimeTicks: nil,
        playbackPositionTicks: nil,
        userData: nil,
        mediaType: "Video",
        indexNumber: nil,
        parentIndexNumber: nil,
        seasonId: nil,
        seriesId: nil,
        seriesName: nil,
        communityRating: nil
    ))
    .environmentObject(AuthManager())
    .environmentObject(ServerManager())
}
