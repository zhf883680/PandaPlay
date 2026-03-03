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
    private var currentItemId: String?
    private var lastSavedPositionMs: Int = 0
    private var lastReportedProgressMs: Int = 0
    private var hasReportedPlaybackStart: Bool = false
    private var hasReportedPlaybackStopped: Bool = false
    private var playSessionId: String = UUID().uuidString
    private var currentSessionId: String?

    func loadPlayer(for mediaItem: MediaItem, serverURL: String, userId: String, accessToken: String) async {
        isLoading = true
        errorMessage = nil

        client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        self.userId = userId
        self.currentItemId = mediaItem.id
        self.lastSavedPositionMs = 0
        self.lastReportedProgressMs = 0
        self.hasReportedPlaybackStart = false
        self.hasReportedPlaybackStopped = false
        self.playSessionId = UUID().uuidString
        self.currentSessionId = nil

        // Get stream URL
        // Prefer direct stream for compatibility with current server setup.
        guard let streamURL = client?.getStreamURL(itemId: mediaItem.id, userId: userId, isStatic: true) else {
            errorMessage = "无法获取播放地址"
            isLoading = false
            return
        }

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

        if subtitleIndexCount > 0 {
            for i in 0..<subtitleIndexCount {
                let index = Int(i)
                let track = SubtitleTrack(id: index, name: "字幕 \(index + 1)", language: nil)
                tracks.append(track)
            }
        }

        subtitleTracks = tracks
    }

    func setSubtitleTrack(index: Int) {
        guard let player = mediaPlayer else { return }

        if index == -1 {
            // Disable subtitles
            player.currentVideoSubTitleIndex = -1
            currentSubtitleIndex = -1
        } else {
            // Set subtitle track index (needs to be Int32)
            player.currentVideoSubTitleIndex = Int32(index)
            currentSubtitleIndex = index

        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
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

        persistProgressIfNeeded()
        reportProgressIfNeeded()
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
        persistProgressForExit()
        reportStoppedIfNeeded()
        stop()
        progressTimer?.invalidate()
        progressTimer = nil
        mediaPlayer = nil
    }

    func restoreProgressIfAvailable() {
        guard let itemId = currentItemId else { return }
        guard let progress = PlaybackProgressManager.shared.loadProgress(itemId: itemId) else { return }
        guard progress.durationTicks > 0 else { return }
        guard progress.progressPercentage >= 0.01, progress.progressPercentage < 0.95 else { return }

        let resumeMs = Int(progress.positionTicks / 10_000)
        if resumeMs > 0 {
            seek(to: resumeMs)
        }
    }

    func reportPlaybackStart(itemId: String) async {
        guard !hasReportedPlaybackStart else { return }
        guard let client else { return }
        hasReportedPlaybackStart = true

        if currentSessionId == nil {
            currentSessionId = await client.getCurrentSessionId(userId: userId)
        }

        let positionTicks = currentTime > 0 ? Int64(currentTime) * 10_000 : nil
        let runTimeTicks = duration > 0 ? Int64(duration) * 10_000 : nil

        do {
            try await client.reportPlaybackStarted(
                itemId: itemId,
                positionTicks: positionTicks,
                runTimeTicks: runTimeTicks,
                playSessionId: playSessionId,
                sessionId: currentSessionId
            )
        } catch {
            hasReportedPlaybackStart = false
            #if DEBUG
            print("❌ [PlayerViewModel] reportPlaybackStart failed: \(error.localizedDescription)")
            #endif
        }
    }

    func reportPlaybackProgress(itemId: String, positionTicks: Int64) async {
        guard let client else { return }
        let runTimeTicks = duration > 0 ? Int64(duration) * 10_000 : nil

        do {
            try await client.reportPlaybackProgress(
                itemId: itemId,
                positionTicks: positionTicks,
                runTimeTicks: runTimeTicks,
                isPaused: !isPlaying,
                playSessionId: playSessionId,
                sessionId: currentSessionId
            )
        } catch {
            #if DEBUG
            print("❌ [PlayerViewModel] reportPlaybackProgress failed: \(error.localizedDescription)")
            #endif
        }
    }

    func reportPlaybackStopped(itemId: String, positionTicks: Int64) async {
        guard let client else { return }
        guard !hasReportedPlaybackStopped else { return }
        hasReportedPlaybackStopped = true

        do {
            try await client.reportPlaybackStopped(
                itemId: itemId,
                positionTicks: positionTicks,
                playSessionId: playSessionId,
                sessionId: currentSessionId
            )
        } catch {
            hasReportedPlaybackStopped = false
            #if DEBUG
            print("❌ [PlayerViewModel] reportPlaybackStopped failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func persistProgressIfNeeded() {
        guard let itemId = currentItemId else { return }
        guard currentTime > 0, duration > 0 else { return }

        // Reduce write frequency to avoid excessive UserDefaults updates.
        if abs(currentTime - lastSavedPositionMs) < 5_000 {
            return
        }

        let positionTicks = Int64(currentTime) * 10_000
        let durationTicks = Int64(duration) * 10_000
        let progressPercentage = Double(currentTime) / Double(duration)

        if progressPercentage >= 0.95 {
            PlaybackProgressManager.shared.clearProgress(itemId: itemId)
        } else {
            PlaybackProgressManager.shared.saveProgress(
                itemId: itemId,
                positionTicks: positionTicks,
                durationTicks: durationTicks
            )
        }

        lastSavedPositionMs = currentTime
    }

    private func persistProgressForExit() {
        guard let itemId = currentItemId else { return }
        guard currentTime > 0, duration > 0 else { return }

        let positionTicks = Int64(currentTime) * 10_000
        let durationTicks = Int64(duration) * 10_000
        let progressPercentage = Double(currentTime) / Double(duration)

        if progressPercentage >= 0.95 {
            PlaybackProgressManager.shared.clearProgress(itemId: itemId)
        } else {
            PlaybackProgressManager.shared.saveProgress(
                itemId: itemId,
                positionTicks: positionTicks,
                durationTicks: durationTicks
            )
        }
    }

    private func reportProgressIfNeeded() {
        guard currentTime > 0 else { return }
        guard let itemId = currentItemId else { return }

        if !hasReportedPlaybackStart {
            Task {
                await reportPlaybackStart(itemId: itemId)
            }
            return
        }

        guard abs(currentTime - lastReportedProgressMs) >= 10_000 else { return }

        let positionTicks = Int64(currentTime) * 10_000
        lastReportedProgressMs = currentTime

        Task {
            await reportPlaybackProgress(itemId: itemId, positionTicks: positionTicks)
        }
    }

    private func reportStoppedIfNeeded() {
        guard let itemId = currentItemId else { return }
        let positionTicks = Int64(max(currentTime, 0)) * 10_000

        Task {
            await reportPlaybackStopped(itemId: itemId, positionTicks: positionTicks)
        }
    }
}

// MARK: - VLCMediaPlayerDelegate
extension PlayerViewModel: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }

        switch player.state {
        case .playing:
            isPlaying = true
            if let itemId = currentItemId {
                Task {
                    await reportPlaybackStart(itemId: itemId)
                }
            }
        case .paused:
            isPlaying = false
            reportProgressIfNeeded()
        case .stopped:
            isPlaying = false
            reportStoppedIfNeeded()
        case .ended:
            isPlaying = false
            if let itemId = currentItemId {
                PlaybackProgressManager.shared.clearProgress(itemId: itemId)
            }
            reportStoppedIfNeeded()
        case .error:
            errorMessage = "播放出错"
            isPlaying = false
            reportStoppedIfNeeded()
        default:
            break
        }
    }
}
