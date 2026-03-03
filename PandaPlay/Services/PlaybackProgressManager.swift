//
//  PlaybackProgressManager.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation

// MARK: - Models

struct PlaybackProgressEntry: Codable {
    let itemId: String
    let positionTicks: Int64
    let durationTicks: Int64
    let lastUpdated: TimeInterval
}

struct PlaybackProgress {
    let itemId: String
    let positionTicks: Int64
    let durationTicks: Int64
    let lastUpdated: Date

    var progressPercentage: Double {
        guard durationTicks > 0 else { return 0 }
        return Double(positionTicks) / Double(durationTicks)
    }
}

// MARK: - Manager

class PlaybackProgressManager {
    static let shared = PlaybackProgressManager()

    private let userDefaults = UserDefaults.standard
    private let progressKey = "playback_progress"

    private init() {}

    // MARK: - Save Progress

    func saveProgress(itemId: String, positionTicks: Int64, durationTicks: Int64) {
        let entry = PlaybackProgressEntry(
            itemId: itemId,
            positionTicks: positionTicks,
            durationTicks: durationTicks,
            lastUpdated: Date().timeIntervalSince1970
        )

        var allProgress = loadAllProgress()
        allProgress[itemId] = entry

        if let data = try? JSONEncoder().encode(allProgress) {
            userDefaults.set(data, forKey: progressKey)
        }
    }

    // MARK: - Load Progress

    func loadProgress(itemId: String) -> PlaybackProgress? {
        let allProgress = loadAllProgress()

        if let entry = allProgress[itemId] {
            return PlaybackProgress(
                itemId: itemId,
                positionTicks: entry.positionTicks,
                durationTicks: entry.durationTicks,
                lastUpdated: Date(timeIntervalSince1970: entry.lastUpdated)
            )
        }

        return nil
    }

    // MARK: - Clear Progress

    func clearProgress(itemId: String) {
        var allProgress = loadAllProgress()
        allProgress.removeValue(forKey: itemId)

        if let data = try? JSONEncoder().encode(allProgress) {
            userDefaults.set(data, forKey: progressKey)
        }
    }

    // MARK: - Recent Progress

    func loadRecentProgress(limit: Int = 20) -> [PlaybackProgress] {
        let allProgress = loadAllProgress()

        return allProgress.values
            .map {
                PlaybackProgress(
                    itemId: $0.itemId,
                    positionTicks: $0.positionTicks,
                    durationTicks: $0.durationTicks,
                    lastUpdated: Date(timeIntervalSince1970: $0.lastUpdated)
                )
            }
            .filter { progress in
                guard progress.durationTicks > 0 else { return false }
                let percentage = progress.progressPercentage
                return percentage >= 0.01 && percentage < 0.95
            }
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Helpers

    private func loadAllProgress() -> [String: PlaybackProgressEntry] {
        if let data = userDefaults.data(forKey: progressKey),
           let decoded = try? JSONDecoder().decode([String: PlaybackProgressEntry].self, from: data) {
            return decoded
        }

        return [:]
    }
}
