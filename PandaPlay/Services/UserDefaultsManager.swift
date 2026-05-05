//
//  UserDefaultsManager.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation

class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    private let userDefaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let selectedServerId = "selected_server_id"
        static let selectedSubtitleLanguage = "selected_subtitle_language"
        static let selectedAudioLanguage = "selected_audio_language"
        static let videoQuality = "video_quality"
        static let lastSyncTime = "last_sync_time"

        // Player
        static let seekStep = "seek_step"

        // Danmaku
        static let danmakuEnabled = "danmaku_enabled"
        static let danmakuOpacity = "danmaku_opacity"
        static let danmakuFontScale = "danmaku_font_scale"
        static let danmakuSpeedScale = "danmaku_speed_scale"
        static let danmakuDensity = "danmaku_density"
        static let danmakuAreaPercent = "danmaku_area_percent"
        static let danmakuHideScroll = "danmaku_hide_scroll"
        static let danmakuHideTop = "danmaku_hide_top"
        static let danmakuHideBottom = "danmaku_hide_bottom"
        static let danmakuOffsetMs = "danmaku_offset_ms"
        static let danmakuAutoLoad = "danmaku_auto_load"
        static let danmakuAutoMatch = "danmaku_auto_match"
        static let danmakuCacheHours = "danmaku_cache_hours"
    }

    private init() {}

    // MARK: - Server

    var selectedServerId: String? {
        get { userDefaults.string(forKey: Keys.selectedServerId) }
        set { userDefaults.set(newValue, forKey: Keys.selectedServerId) }
    }

    // MARK: - Playback Preferences

    var selectedSubtitleLanguage: String? {
        get { userDefaults.string(forKey: Keys.selectedSubtitleLanguage) }
        set { userDefaults.set(newValue, forKey: Keys.selectedSubtitleLanguage) }
    }

    var selectedAudioLanguage: String? {
        get { userDefaults.string(forKey: Keys.selectedAudioLanguage) }
        set { userDefaults.set(newValue, forKey: Keys.selectedAudioLanguage) }
    }

    var videoQuality: VideoQuality {
        get {
            let rawValue = userDefaults.integer(forKey: Keys.videoQuality)
            return VideoQuality(rawValue: rawValue) ?? .auto
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.videoQuality)
        }
    }

    // MARK: - Player Settings

    var seekStep: Int {
        get {
            let value = userDefaults.integer(forKey: Keys.seekStep)
            return value == 0 ? 10 : value
        }
        set { userDefaults.set(newValue, forKey: Keys.seekStep) }
    }

    // MARK: - Danmaku Settings

    var danmakuEnabled: Bool {
        get { userDefaults.object(forKey: Keys.danmakuEnabled) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: Keys.danmakuEnabled) }
    }

    var danmakuOpacity: Double {
        get { userDefaults.object(forKey: Keys.danmakuOpacity) as? Double ?? 1.0 }
        set { userDefaults.set(newValue, forKey: Keys.danmakuOpacity) }
    }

    var danmakuFontScale: Double {
        get { userDefaults.object(forKey: Keys.danmakuFontScale) as? Double ?? 1.0 }
        set { userDefaults.set(newValue, forKey: Keys.danmakuFontScale) }
    }

    var danmakuSpeedScale: Double {
        get { userDefaults.object(forKey: Keys.danmakuSpeedScale) as? Double ?? 1.0 }
        set { userDefaults.set(newValue, forKey: Keys.danmakuSpeedScale) }
    }

    var danmakuDensity: Int {
        get { userDefaults.integer(forKey: Keys.danmakuDensity) }
        set { userDefaults.set(newValue, forKey: Keys.danmakuDensity) }
    }

    var danmakuAreaPercent: Double {
        get { userDefaults.object(forKey: Keys.danmakuAreaPercent) as? Double ?? 1.0 }
        set { userDefaults.set(newValue, forKey: Keys.danmakuAreaPercent) }
    }

    var danmakuHideScroll: Bool {
        get { userDefaults.object(forKey: Keys.danmakuHideScroll) as? Bool ?? false }
        set { userDefaults.set(newValue, forKey: Keys.danmakuHideScroll) }
    }

    var danmakuHideTop: Bool {
        get { userDefaults.object(forKey: Keys.danmakuHideTop) as? Bool ?? false }
        set { userDefaults.set(newValue, forKey: Keys.danmakuHideTop) }
    }

    var danmakuHideBottom: Bool {
        get { userDefaults.object(forKey: Keys.danmakuHideBottom) as? Bool ?? false }
        set { userDefaults.set(newValue, forKey: Keys.danmakuHideBottom) }
    }

    var danmakuOffsetMs: Int {
        get { userDefaults.integer(forKey: Keys.danmakuOffsetMs) }
        set { userDefaults.set(newValue, forKey: Keys.danmakuOffsetMs) }
    }

    var danmakuAutoLoad: Bool {
        get { userDefaults.object(forKey: Keys.danmakuAutoLoad) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: Keys.danmakuAutoLoad) }
    }

    var danmakuAutoMatch: Bool {
        get { userDefaults.object(forKey: Keys.danmakuAutoMatch) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: Keys.danmakuAutoMatch) }
    }

    var danmakuCacheHours: Int {
        get {
            let value = userDefaults.integer(forKey: Keys.danmakuCacheHours)
            return value == 0 ? 720 : value
        }
        set { userDefaults.set(newValue, forKey: Keys.danmakuCacheHours) }
    }

    // MARK: - Sync

    var lastSyncTime: Date? {
        get {
            guard let timestamp = userDefaults.object(forKey: Keys.lastSyncTime) as? TimeInterval else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            if let newValue = newValue {
                userDefaults.set(newValue.timeIntervalSince1970, forKey: Keys.lastSyncTime)
            } else {
                userDefaults.removeObject(forKey: Keys.lastSyncTime)
            }
        }
    }

    func updateLastSyncTime() {
        lastSyncTime = Date()
    }

    // MARK: - Clear All

    func clearAll() {
        for key in [
            Keys.selectedServerId, Keys.selectedSubtitleLanguage,
            Keys.selectedAudioLanguage, Keys.videoQuality, Keys.lastSyncTime,
            Keys.seekStep,
            Keys.danmakuEnabled, Keys.danmakuOpacity, Keys.danmakuFontScale,
            Keys.danmakuSpeedScale, Keys.danmakuDensity, Keys.danmakuAreaPercent,
            Keys.danmakuHideScroll, Keys.danmakuHideTop, Keys.danmakuHideBottom,
            Keys.danmakuOffsetMs, Keys.danmakuAutoLoad, Keys.danmakuAutoMatch,
            Keys.danmakuCacheHours
        ] {
            userDefaults.removeObject(forKey: key)
        }
    }
}

// MARK: - Models

enum VideoQuality: Int, CaseIterable {
    case auto = 0
    case max = 1
    case high = 2
    case medium = 3
    case low = 4

    var displayName: String {
        switch self {
        case .auto: return "自动"
        case .max: return "最高"
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}
