//
//  PlayerViewModel.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation
import SwiftUI
import Combine
#if os(iOS)
import MobileVLCKit
#elseif os(tvOS)
import TVVLCKit
#endif

// MARK: - Subtitle Track Model
struct SubtitleTrack: Identifiable, Equatable {
    let id: Int
    let name: String
    let language: String?

    var displayName: String {
        if id == -1 {
            return "关闭"
        }
        if let lang = language, !lang.isEmpty {
            return lang
        }
        return "字幕 \(id)"
    }

    static let off = SubtitleTrack(id: -1, name: "Off", language: nil)
}

@MainActor
class PlayerViewModel: NSObject, ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var mediaPlayer: VLCMediaPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Int = 0
    @Published var duration: Int = 0
    @Published var subtitleTracks: [SubtitleTrack] = []
    @Published var currentSubtitleIndex: Int = -1

    private var client: EmbyClient?
    private var userId: String?
    private var progressTimer: Timer?

    func loadPlayer(for mediaItem: MediaItem, serverURL: String, userId: String, accessToken: String) async {
        isLoading = true
        errorMessage = nil

        client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        self.userId = userId

        // Get stream URL
        guard let streamURL = client?.getStreamURL(itemId: mediaItem.id, userId: userId, isStatic: false) else {
            errorMessage = "无法获取播放地址"
            isLoading = false
            return
        }

        print("🎬 [PlayerViewModel] Stream URL: \(streamURL.absoluteString)")

        // Create VLC Media
        let media = VLCMedia(url: streamURL)

        // Set HTTP headers for authentication
        let options: [String: Any] = [
            "http-referrer": serverURL,
            "http-user-agent": "PandaPlay/1.0"
        ]
        media.addOptions(options)

        // Create and configure player
        let player = VLCMediaPlayer()
        player.media = media

        // Set up delegate for callbacks
        player.delegate = self

        mediaPlayer = player
        isLoading = false

        // Start progress timer
        startProgressTimer()

        // Load subtitle tracks after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadSubtitleTracks()
        }
    }

    private func loadSubtitleTracks() {
        guard let player = mediaPlayer else { return }

        var tracks: [SubtitleTrack] = [.off]

        // Get subtitle tracks from player
        let subtitleIndexCount = player.numberOfSubtitlesTracks

        print("🎬 [PlayerViewModel] numberOfSubtitlesTracks: \(subtitleIndexCount)")

        if subtitleIndexCount > 0 {
            for i in 0..<subtitleIndexCount {
                let index = Int(i)
                let track = SubtitleTrack(id: index, name: "字幕 \(index + 1)", language: nil)
                tracks.append(track)
                print("🎬 [PlayerViewModel] Found subtitle track: \(track.displayName)")
            }
        }

        subtitleTracks = tracks
        print("🎬 [PlayerViewModel] Loaded \(tracks.count) subtitle tracks")
    }

    func setSubtitleTrack(index: Int) {
        guard let player = mediaPlayer else { return }

        if index == -1 {
            // Disable subtitles
            player.currentVideoSubTitleIndex = -1
            currentSubtitleIndex = -1
            print("🎬 [PlayerViewModel] Subtitles disabled")
        } else {
            // Set subtitle track index (needs to be Int32)
            player.currentVideoSubTitleIndex = Int32(index)
            currentSubtitleIndex = index

            // Find track name for logging
            if let track = subtitleTracks.first(where: { $0.id == index }) {
                print("🎬 [PlayerViewModel] Subtitle changed to: \(track.displayName)")
            } else {
                print("🎬 [PlayerViewModel] Subtitle changed to index: \(index)")
            }
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }

    private func updateProgress() {
        guard let player = mediaPlayer else { return }
        currentTime = Int(player.time.intValue)
        let mediaDuration = player.media?.length.intValue ?? 0
        if mediaDuration > 0 {
            duration = Int(mediaDuration)
        }
        isPlaying = player.isPlaying
    }

    func play() {
        mediaPlayer?.play()
    }

    func pause() {
        mediaPlayer?.pause()
    }

    func stop() {
        mediaPlayer?.stop()
    }

    func seek(to time: Int) {
        // time in milliseconds
        mediaPlayer?.time = VLCTime(int: Int32(time))
    }

    func cleanup() {
        stop()
        progressTimer?.invalidate()
        progressTimer = nil
        mediaPlayer = nil
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

// MARK: - VLCMediaPlayerDelegate
extension PlayerViewModel: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }

        switch player.state {
        case .playing:
            print("🎬 [PlayerViewModel] Playing")
            isPlaying = true
        case .paused:
            print("🎬 [PlayerViewModel] Paused")
            isPlaying = false
        case .stopped:
            print("🎬 [PlayerViewModel] Stopped")
            isPlaying = false
        case .ended:
            print("🎬 [PlayerViewModel] Ended")
            isPlaying = false
        case .error:
            print("🎬 [PlayerViewModel] Error")
            errorMessage = "播放出错"
            isPlaying = false
        default:
            break
        }
    }
}
