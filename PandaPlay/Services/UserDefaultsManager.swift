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
        userDefaults.removeObject(forKey: Keys.selectedServerId)
        userDefaults.removeObject(forKey: Keys.selectedSubtitleLanguage)
        userDefaults.removeObject(forKey: Keys.selectedAudioLanguage)
        userDefaults.removeObject(forKey: Keys.videoQuality)
        userDefaults.removeObject(forKey: Keys.lastSyncTime)
    }
}

// MARK: - Models

enum VideoQuality: Int {
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
