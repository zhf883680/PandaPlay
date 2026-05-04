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

// MARK: - Audio Track Model
struct AudioTrack: Identifiable, Equatable {
    let id: Int
    let name: String
    let language: String?

    var displayName: String {
        if let lang = language, !lang.isEmpty { return lang }
        return "音轨 \(id + 1)"
    }
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
    @Published var audioTracks: [AudioTrack] = []
    @Published var currentAudioIndex: Int = 0

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
    private var currentMediaItem: MediaItem?
    private var currentServerURL: String?
    private var currentAccessToken: String?
    private var hasRetriedWithHLS: Bool = false

    func loadPlayer(for mediaItem: MediaItem, serverURL: String, userId: String, accessToken: String) async {
        isLoading = true
        errorMessage = nil
        hasRetriedWithHLS = false

        client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        self.userId = userId
        self.currentItemId = mediaItem.id
        self.currentMediaItem = mediaItem
        self.currentServerURL = serverURL
        self.currentAccessToken = accessToken
        self.lastSavedPositionMs = 0
        self.lastReportedProgressMs = 0
        self.hasReportedPlaybackStart = false
        self.hasReportedPlaybackStopped = false
        self.playSessionId = UUID().uuidString
        self.currentSessionId = nil

        // Step 1: Try PlaybackInfo API to get server-supported stream URLs
        if let streamURL = await getStreamURLFromPlaybackInfo(itemId: mediaItem.id, userId: userId, accessToken: accessToken) {
            setupPlayer(with: streamURL, serverURL: serverURL, accessToken: accessToken)
            return
        }

        // Step 2: Fallback to manually constructed URL
        guard let streamURL = buildStreamURL(for: mediaItem, userId: userId) else {
            errorMessage = "无法获取播放地址"
            isLoading = false
            return
        }

        setupPlayer(with: streamURL, serverURL: serverURL, accessToken: accessToken)
    }

    private func getStreamURLFromPlaybackInfo(itemId: String, userId: String, accessToken: String) async -> URL? {
        guard let client else { return nil }

        do {
            let info = try await client.getPlaybackInfo(itemId: itemId, userId: userId)
            guard let sources = info.mediaSources, !sources.isEmpty else {
                return nil
            }

            // Prefer transcoding URL (most compatible)
            if let transcodingUrl = sources.first?.transcodingUrl {
                let fullURL: String
                if transcodingUrl.hasPrefix("http") {
                    fullURL = transcodingUrl
                } else {
                    fullURL = client.baseURL + transcodingUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                }
                return URL(string: fullURL)
            }

            // Try direct stream URL
            if let directUrl = sources.first?.directStreamUrl {
                let fullURL: String
                if directUrl.hasPrefix("http") {
                    fullURL = directUrl
                } else {
                    fullURL = client.baseURL + directUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                }
                return URL(string: fullURL)
            }

            // Last resort: construct URL with MediaSourceId
            if let sourceId = sources.first?.id {
                return client.getStreamURL(itemId: itemId, userId: userId, isStatic: true, mediaSourceId: sourceId)
            }

            return nil
        } catch {
            return nil
        }
    }

    private func buildStreamURL(for mediaItem: MediaItem, userId: String) -> URL? {
        let quality = UserDefaultsManager.shared.videoQuality
        switch quality {
        case .auto, .max:
            return client?.getStreamURL(itemId: mediaItem.id, userId: userId, isStatic: true)
        case .high:
            return client?.getMasterM3U8URL(itemId: mediaItem.id, userId: userId, maxBitrate: 12000000)
        case .medium:
            return client?.getMasterM3U8URL(itemId: mediaItem.id, userId: userId, maxBitrate: 4000000)
        case .low:
            return client?.getMasterM3U8URL(itemId: mediaItem.id, userId: userId, maxBitrate: 1500000)
        }
    }

    private func setupPlayer(with streamURL: URL, serverURL: String, accessToken: String) {
        let media = VLCMedia(url: streamURL)

        media.addOption(":http-user-agent=PandaPlay/1.0")
        media.addOption(":http-referrer=\(serverURL)")
        media.addOption(":http-header=X-Emby-Token:\(accessToken)")
        media.addOption(":no-validate-certificate")

        let player = VLCMediaPlayer()
        player.media = media
        player.delegate = self

        mediaPlayer = player
        isLoading = false

        startProgressTimer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadSubtitleTracks()
            self.loadAudioTracks()
        }
    }

    private func retryWithHLS() {
        guard !hasRetriedWithHLS,
              let mediaItem = currentMediaItem,
              let userId = userId,
              let serverURL = currentServerURL,
              let accessToken = currentAccessToken else { return }

        hasRetriedWithHLS = true

        guard let hlsURL = client?.getMasterM3U8URL(itemId: mediaItem.id, userId: userId, maxBitrate: 40000000) else {
            errorMessage = "播放出错：无法获取播放地址"
            return
        }

        setupPlayer(with: hlsURL, serverURL: serverURL, accessToken: accessToken)
        play()
    }

    private func loadSubtitleTracks() {
        guard let player = mediaPlayer else { return }

        var tracks: [SubtitleTrack] = [.off]

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

    private func loadAudioTracks() {
        guard let player = mediaPlayer else { return }

        let count = Int(player.numberOfAudioTracks)
        var tracks: [AudioTrack] = []
        for i in 0..<count {
            tracks.append(AudioTrack(id: i, name: "音轨 \(i + 1)", language: nil))
        }
        audioTracks = tracks
        if let first = tracks.first { currentAudioIndex = first.id }
    }

    func setSubtitleTrack(index: Int) {
        guard let player = mediaPlayer else { return }

        if index == -1 {
            player.currentVideoSubTitleIndex = -1
            currentSubtitleIndex = -1
        } else {
            player.currentVideoSubTitleIndex = Int32(index)
            currentSubtitleIndex = index
        }
    }

    func setAudioTrack(index: Int) {
        guard let player = mediaPlayer else { return }
        player.currentAudioTrackIndex = Int32(index)
        currentAudioIndex = index
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
        }
    }

    private func persistProgressIfNeeded() {
        guard let itemId = currentItemId else { return }
        guard currentTime > 0, duration > 0 else { return }

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
            if hasRetriedWithHLS {
                errorMessage = "播放出错"
            } else {
                retryWithHLS()
            }
            isPlaying = false
            reportStoppedIfNeeded()
        default:
            break
        }
    }
}
