//
//  PlayerView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI
import AVFoundation
#if os(iOS)
import MobileVLCKit
import UIKit
#elseif os(tvOS)
import TVVLCKit
import TVUIKit
#endif

#if os(iOS)
// MARK: - UIViewRepresentable for VLCMediaPlayer (iOS)
struct VLCPlayerView: UIViewRepresentable {
    let player: VLCMediaPlayer?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let player = player {
            player.drawable = view
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let player = player, player.drawable == nil {
            player.drawable = uiView
        }
    }
}
#elseif os(tvOS)
// MARK: - UIViewRepresentable for VLCMediaPlayer (tvOS)
struct VLCPlayerView: UIViewRepresentable {
    let player: VLCMediaPlayer?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let player = player {
            player.drawable = view
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let player = player, player.drawable == nil {
            player.drawable = uiView
        }
    }
}
#endif

struct PlayerView: View {
    let mediaItem: MediaItem
    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager

    @State private var showControls = true
    @State private var controlsTimer: Task<Void, Never>?
    @State private var showSubtitleMenu = false

    private var loadingScale: CGFloat {
        DeviceType.current == .iPhone ? 1.2 : (DeviceType.current == .iPad ? 1.5 : 2)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = viewModel.mediaPlayer {
                // Video player view
                VLCPlayerView(player: player)
                    .ignoresSafeArea()

                // Player controls overlay
                if showControls {
                    controlsOverlay
                        .transition(.opacity)
                }
            } else if viewModel.isLoading {
                VStack(spacing: DeviceType.current == .iPhone ? 12 : 20) {
                    ProgressView()
                        .scaleEffect(loadingScale)
                        .tint(.white)
                    Text("加载中...")
                        .foregroundColor(.white)
                        .font(DeviceType.current == .iPhone ? .subheadline : .body)
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: DeviceType.current == .iPhone ? 12 : 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: DeviceType.current == .iPhone ? 36 : 50))
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.white)
                        .font(DeviceType.current == .iPhone ? .subheadline : .body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DeviceType.current == .iPhone ? 20 : 40)
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
                .padding(DeviceType.current == .iPhone ? 20 : 40)
            }
        }
        #if os(iOS)
        .onTapGesture(count: 2) {
            // Double tap to toggle controls on iOS
            withAnimation {
                showControls.toggle()
            }
            resetControlsTimer()
        }
        #endif
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
                // Auto play after loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.play()
                }
            }
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(DeviceType.current == .iPhone ? 8 : 12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }

                Spacer()

                Text(mediaItem.name ?? "播放中")
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(DeviceType.current == .iPhone ? 8 : 12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color.black.opacity(0.4))

            Spacer()

            // Bottom controls
            VStack(spacing: DeviceType.current == .iPhone ? 8 : 12) {
                // Progress bar
                VStack(spacing: 4) {
                    HStack {
                        Text(formatTime(viewModel.currentTime))
                            .font(.caption)
                            .foregroundColor(.white)

                        Spacer()

                        Text(formatTime(viewModel.duration))
                            .font(.caption)
                            .foregroundColor(.white)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: DeviceType.current == .iPhone ? 4 : 6)

                            // Progress
                            if viewModel.duration > 0 {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.currentTime) / CGFloat(viewModel.duration), height: DeviceType.current == .iPhone ? 4 : 6)
                            }
                        }
                        .cornerRadius(2)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let percentage = value.location.x / geometry.size.width
                                    let newTime = Int(Double(percentage) * Double(viewModel.duration))
                                    viewModel.seek(to: newTime * 1000)
                                }
                        )
                    }
                    .frame(height: DeviceType.current == .iPhone ? 4 : 6)
                }

                // Playback controls
                HStack(spacing: DeviceType.current == .iPhone ? 25 : 45) {
                    // Rewind 10 seconds
                    Button(action: {
                        let newTime = max(0, viewModel.currentTime - 10000)
                        viewModel.seek(to: newTime)
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    // Subtitles button
                    Button(action: {
                        showSubtitleMenu.toggle()
                    }) {
                        ZStack(alignment: .topLeading) {
                            Image(systemName: "captions.bubble")
                                .font(.title2)
                                .foregroundColor(.white)

                            if viewModel.currentSubtitleIndex != -1 {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -8, y: -4)
                            }
                        }
                    }
                    #if os(iOS)
                    .confirmationDialog("选择字幕", isPresented: $showSubtitleMenu, titleVisibility: .visible) {
                        ForEach(viewModel.subtitleTracks) { track in
                            Button(track.displayName) {
                                viewModel.setSubtitleTrack(index: track.id)
                            }
                        }
                    }
                    #elseif os(tvOS)
                    .contextMenu {
                        ForEach(viewModel.subtitleTracks) { track in
                            Button(track.displayName) {
                                viewModel.setSubtitleTrack(index: track.id)
                            }
                        }
                    }
                    #endif

                    // Play/Pause
                    Button(action: {
                        if viewModel.isPlaying {
                            viewModel.pause()
                        } else {
                            viewModel.play()
                        }
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: DeviceType.current == .iPhone ? 50 : 60))
                            .foregroundColor(.white)
                    }

                    // Forward 10 seconds
                    Button(action: {
                        let newTime = min(viewModel.duration, viewModel.currentTime + 10000)
                        viewModel.seek(to: newTime)
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, DeviceType.current == .iPhone ? 8 : 12)
            }
            .padding()
            .background(Color.black.opacity(0.4))
        }
    }

    private func formatTime(_ milliseconds: Int) -> String {
        let seconds = milliseconds / 1000
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func resetControlsTimer() {
        controlsTimer?.cancel()
        controlsTimer = Task {
            try? await Task.sleep(nanoseconds: UInt64(4 * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation {
                    showControls = false
                }
            }
        }
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
