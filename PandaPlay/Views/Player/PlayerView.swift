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
    let onReady: () -> Void

    class Coordinator {
        weak var boundPlayer: VLCMediaPlayer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let player = player {
            player.drawable = view
            context.coordinator.boundPlayer = player
        }

        DispatchQueue.main.async {
            onReady()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let player = player {
            let drawable = player.drawable as AnyObject?
            if context.coordinator.boundPlayer !== player || drawable !== uiView {
                player.drawable = uiView
                context.coordinator.boundPlayer = player
            }
        } else if let oldPlayer = context.coordinator.boundPlayer {
            oldPlayer.drawable = nil
            context.coordinator.boundPlayer = nil
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        if let player = coordinator.boundPlayer {
            let drawable = player.drawable as AnyObject?
            if drawable === uiView {
                player.drawable = nil
            }
            coordinator.boundPlayer = nil
        }
    }
}
#elseif os(tvOS)
// MARK: - UIViewRepresentable for VLCMediaPlayer (tvOS)
struct VLCPlayerView: UIViewRepresentable {
    let player: VLCMediaPlayer?
    let onReady: () -> Void

    class Coordinator {
        weak var boundPlayer: VLCMediaPlayer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let player = player {
            player.drawable = view
            context.coordinator.boundPlayer = player
        }

        DispatchQueue.main.async {
            onReady()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let player = player {
            let drawable = player.drawable as AnyObject?
            if context.coordinator.boundPlayer !== player || drawable !== uiView {
                player.drawable = uiView
                context.coordinator.boundPlayer = player
            }
        } else if let oldPlayer = context.coordinator.boundPlayer {
            oldPlayer.drawable = nil
            context.coordinator.boundPlayer = nil
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        if let player = coordinator.boundPlayer {
            let drawable = player.drawable as AnyObject?
            if drawable === uiView {
                player.drawable = nil
            }
            coordinator.boundPlayer = nil
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
    @State private var showAudioMenu = false
    @State private var playerViewReady = false
    @State private var pendingAutoPlay = false

    #if os(tvOS)
    @FocusState private var focusedButton: FocusedButton?
    enum FocusedButton {
        case back, close, rewind, audio, subtitles, playPause, forward
    }
    #endif

    private var loadingScale: CGFloat {
        DeviceType.current == .iPhone ? 1.2 : (DeviceType.current == .iPad ? 1.5 : 2)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = viewModel.mediaPlayer {
                // Video player view
                VLCPlayerView(player: player) {
                    playerViewReady = true
                    startPlaybackIfReady()
                }
                    .ignoresSafeArea()
                    #if os(tvOS)
                    .onPlayPauseCommand {
                        // Handle Siri Remote play/pause button
                        if viewModel.isPlaying {
                            viewModel.pause()
                        } else {
                            viewModel.play()
                        }
                    }
                    .onTapGesture(count: 1) {
                        // Single tap to toggle controls on tvOS
                        withAnimation {
                            showControls.toggle()
                        }
                        resetControlsTimer()
                    }
                    #endif

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
                pendingAutoPlay = true
                startPlaybackIfReady()
            }
        }
        .onDisappear {
            pendingAutoPlay = false
            playerViewReady = false
            viewModel.cleanup()
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
                        .padding(DeviceType.current == .iPhone ? 8 : 16)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                #if os(tvOS)
                .focusable()
                .focused($focusedButton, equals: .back)
                #endif

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
                        .padding(DeviceType.current == .iPhone ? 8 : 16)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                #if os(tvOS)
                .focusable()
                .focused($focusedButton, equals: .close)
                #endif
            }
            .padding()
            .background(Color.black.opacity(0.4))

            Spacer()

            // Bottom controls
            VStack(spacing: DeviceType.current == .iPhone ? 8 : 16) {
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
                                .frame(height: DeviceType.current == .iPhone ? 4 : 8)

                            // Progress
                            if viewModel.duration > 0 {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.currentTime) / CGFloat(viewModel.duration), height: DeviceType.current == .iPhone ? 4 : 8)
                            }
                        }
                        .cornerRadius(4)
                        #if os(iOS)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let percentage = value.location.x / geometry.size.width
                                    let newTime = Int(Double(percentage) * Double(viewModel.duration))
                                    viewModel.seek(to: newTime * 1000)
                                }
                        )
                        #elseif os(tvOS)
                        .focusable()
                        #endif
                    }
                    .frame(height: DeviceType.current == .iPhone ? 4 : 8)
                }

                // Playback controls
                HStack(spacing: DeviceType.current == .iPhone ? 25 : 60) {
                    // Rewind 10 seconds
                    Button(action: {
                        let newTime = max(0, viewModel.currentTime - 10000)
                        viewModel.seek(to: newTime)
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(DeviceType.current == .iPhone ? .title2 : .system(size: 48))
                            .foregroundColor(.white)
                            .frame(width: DeviceType.current == .iPhone ? 44 : 80,
                                   height: DeviceType.current == .iPhone ? 44 : 80)
                    }
                    #if os(tvOS)
                    .focusable()
                    .focused($focusedButton, equals: .rewind)
                    #endif

                    // Audio track button
                    Button(action: {
                        showAudioMenu.toggle()
                    }) {
                        ZStack(alignment: .topLeading) {
                            Image(systemName: "speaker.wave.2")
                                .font(DeviceType.current == .iPhone ? .title2 : .system(size: 48))
                                .foregroundColor(.white)
                                .frame(width: DeviceType.current == .iPhone ? 44 : 80,
                                       height: DeviceType.current == .iPhone ? 44 : 80)

                            if viewModel.audioTracks.count > 1 {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: DeviceType.current == .iPhone ? 8 : 12, height: DeviceType.current == .iPhone ? 8 : 12)
                                    .offset(x: DeviceType.current == .iPhone ? -8 : -12, y: DeviceType.current == .iPhone ? -4 : -6)
                            }
                        }
                    }
                    #if os(tvOS)
                    .focusable()
                    .focused($focusedButton, equals: .audio)
                    #endif
                    .confirmationDialog("选择音轨", isPresented: $showAudioMenu, titleVisibility: .visible) {
                        ForEach(viewModel.audioTracks) { track in
                            Button(track.id == viewModel.currentAudioIndex ? "\(track.displayName) ✓" : track.displayName) {
                                viewModel.setAudioTrack(index: track.id)
                            }
                        }
                    }

                    // Subtitles button
                    Button(action: {
                        showSubtitleMenu.toggle()
                    }) {
                        ZStack(alignment: .topLeading) {
                            Image(systemName: "captions.bubble")
                                .font(DeviceType.current == .iPhone ? .title2 : .system(size: 48))
                                .foregroundColor(.white)
                                .frame(width: DeviceType.current == .iPhone ? 44 : 80,
                                       height: DeviceType.current == .iPhone ? 44 : 80)

                            if viewModel.currentSubtitleIndex != -1 {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: DeviceType.current == .iPhone ? 8 : 12, height: DeviceType.current == .iPhone ? 8 : 12)
                                    .offset(x: DeviceType.current == .iPhone ? -8 : -12, y: DeviceType.current == .iPhone ? -4 : -6)
                            }
                        }
                    }
                    #if os(tvOS)
                    .focusable()
                    .focused($focusedButton, equals: .subtitles)
                    #endif
                    #if os(iOS)
                    .confirmationDialog("选择字幕", isPresented: $showSubtitleMenu, titleVisibility: .visible) {
                        ForEach(viewModel.subtitleTracks) { track in
                            Button(track.displayName) {
                                viewModel.setSubtitleTrack(index: track.id)
                            }
                        }
                    }
                    #elseif os(tvOS)
                    .confirmationDialog("选择字幕", isPresented: $showSubtitleMenu, titleVisibility: .visible) {
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
                            .font(.system(size: DeviceType.current == .iPhone ? 50 : 72))
                            .foregroundColor(.white)
                            .frame(width: DeviceType.current == .iPhone ? 60 : 100,
                                   height: DeviceType.current == .iPhone ? 60 : 100)
                    }
                    #if os(tvOS)
                    .focusable()
                    .focused($focusedButton, equals: .playPause)
                    #endif

                    // Forward 10 seconds
                    Button(action: {
                        let newTime = min(viewModel.duration, viewModel.currentTime + 10000)
                        viewModel.seek(to: newTime)
                    }) {
                        Image(systemName: "goforward.10")
                            .font(DeviceType.current == .iPhone ? .title2 : .system(size: 48))
                            .foregroundColor(.white)
                            .frame(width: DeviceType.current == .iPhone ? 44 : 80,
                                   height: DeviceType.current == .iPhone ? 44 : 80)
                    }
                    #if os(tvOS)
                    .focusable()
                    .focused($focusedButton, equals: .forward)
                    #endif
                }
                .padding(.vertical, DeviceType.current == .iPhone ? 8 : 16)
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

    private func startPlaybackIfReady() {
        guard pendingAutoPlay, playerViewReady else { return }
        pendingAutoPlay = false
        viewModel.restoreProgressIfAvailable()
        viewModel.play()
        #if os(tvOS)
        focusedButton = .playPause
        #endif
    }
}

#Preview {
    PlayerView(mediaItem: MediaItem(
        id: "1",
        name: "示例电影",
        type: "Movie",
        overview: "示例描述",
        productionYear: 2024,
        mediaType: "Video"
    ))
    .environmentObject(AuthManager())
    .environmentObject(ServerManager())
}
