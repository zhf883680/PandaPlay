//
//  DanmakuService.swift
//  PandaPlay
//
//  Handles danmaku matching, caching, and loading logic.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Media Context

struct DanmakuMediaContext {
    let serverId: String
    let mediaId: String
    let title: String
    let originalTitle: String?
    let seriesName: String?
    let productionYear: Int?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let durationMs: Double?
    let fileName: String?

    var cacheKey: String {
        "\(serverId)_\(mediaId)"
    }

    var searchKeyword: String {
        if let series = seriesName, !series.isEmpty {
            var keyword = series
            if let season = seasonNumber {
                keyword += " S\(String(format: "%02d", season))"
            }
            if let episode = episodeNumber {
                keyword += "E\(String(format: "%02d", episode))"
            }
            return keyword
        }
        return title
    }
}

// MARK: - Danmaku Service

@MainActor
class DanmakuService: ObservableObject {
    @Published var comments: [DanmakuComment] = []
    @Published var isMatching: Bool = false
    @Published var needsManualMatch: Bool = false
    @Published var matchTitle: String?
    @Published var errorMessage: String?

    private let client = DandanPlayClient.shared
    private let userDefaults = UserDefaults.standard

    private static let matchCacheKey = "danmaku_match_cache"
    private static let commentsCachePrefix = "danmaku_comments_"

    // MARK: - Auto-load

    func prepareDanmaku(context: DanmakuMediaContext) async {
        guard UserDefaultsManager.shared.danmakuAutoLoad else { return }
        guard UserDefaultsManager.shared.danmakuEnabled else { return }

        isMatching = true
        errorMessage = nil
        needsManualMatch = false

        // Check manual match cache first
        if let cachedEpisodeId = loadManualMatch(cacheKey: context.cacheKey) {
            await loadComments(episodeId: cachedEpisodeId)
            isMatching = false
            return
        }

        // Check auto-match cache
        if let cachedEpisodeId = loadAutoMatchCache(cacheKey: context.cacheKey) {
            await loadComments(episodeId: cachedEpisodeId)
            isMatching = false
            return
        }

        // Auto-match
        if UserDefaultsManager.shared.danmakuAutoMatch {
            await autoMatch(context: context)
        } else {
            needsManualMatch = true
            isMatching = false
        }
    }

    // MARK: - Auto Match

    private func autoMatch(context: DanmakuMediaContext) async {
        // Try file-based match first
        if let fileName = context.fileName {
            do {
                let result = try await client.match(
                    fileName: fileName,
                    videoDuration: context.durationMs.map { Int($0 / 1000) }
                )

                if let match = result.matches?.first,
                   let episodeIdStr = match.episodeId,
                   let episodeId = Int(episodeIdStr) {
                    matchTitle = match.animeTitle ?? match.episodeTitle
                    saveAutoMatchCache(cacheKey: context.cacheKey, episodeId: episodeId)
                    await loadComments(episodeId: episodeId)
                    isMatching = false
                    return
                }
            } catch {
                // Fall through to search-based matching
            }
        }

        // Search-based match
        let keyword = context.searchKeyword
        do {
            let searchResult = try await client.searchEpisodes(keyword: keyword)

            if let anime = searchResult.animes?.first,
               let episodes = anime.episodes,
               let episode = episodes.first,
               let episodeId = episode.episodeId {
                matchTitle = "\(anime.animeTitle ?? "") - \(episode.episodeTitle ?? "")"
                saveAutoMatchCache(cacheKey: context.cacheKey, episodeId: episodeId)
                await loadComments(episodeId: episodeId)
                isMatching = false
                return
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        needsManualMatch = true
        isMatching = false
    }

    // MARK: - Manual Match

    func searchCandidates(keyword: String) async -> [DanmakuSearchResult.DanmakuAnime] {
        do {
            let result = try await client.searchEpisodes(keyword: keyword)
            return result.animes ?? []
        } catch {
            return []
        }
    }

    func manualMatch(context: DanmakuMediaContext, episodeId: Int, title: String?) async {
        isMatching = true
        matchTitle = title
        saveManualMatch(cacheKey: context.cacheKey, episodeId: episodeId)
        await loadComments(episodeId: episodeId)
        needsManualMatch = false
        isMatching = false
    }

    // MARK: - Load Comments

    private func loadComments(episodeId: Int) async {
        // Check comments cache
        let cacheKey = DanmakuService.commentsCachePrefix + "\(episodeId)"
        let cacheHours = UserDefaultsManager.shared.danmakuCacheHours

        if let cached = loadCommentsCache(key: cacheKey, maxAgeHours: cacheHours) {
            comments = cached
            return
        }

        // Fetch from API
        do {
            let fetched = try await client.fetchComments(episodeId: episodeId)
            comments = fetched
            saveCommentsCache(key: cacheKey, comments: fetched)
        } catch {
            errorMessage = error.localizedDescription
            comments = []
        }
    }

    // MARK: - Clear

    func clearDanmaku() {
        comments = []
        matchTitle = nil
        needsManualMatch = false
        errorMessage = nil
    }

    // MARK: - Cache Helpers

    private func loadManualMatch(cacheKey: String) -> Int? {
        let key = "danmaku_manual_\(cacheKey)"
        return userDefaults.object(forKey: key) as? Int
    }

    private func saveManualMatch(cacheKey: String, episodeId: Int) {
        let key = "danmaku_manual_\(cacheKey)"
        userDefaults.set(episodeId, forKey: key)
    }

    private func loadAutoMatchCache(cacheKey: String) -> Int? {
        let key = "danmaku_auto_\(cacheKey)"
        return userDefaults.object(forKey: key) as? Int
    }

    private func saveAutoMatchCache(cacheKey: String, episodeId: Int) {
        let key = "danmaku_auto_\(cacheKey)"
        userDefaults.set(episodeId, forKey: key)
    }

    private func loadCommentsCache(key: String, maxAgeHours: Int) -> [DanmakuComment]? {
        guard let data = userDefaults.data(forKey: key + "_data"),
              let timestamp = userDefaults.object(forKey: key + "_ts") as? Date else {
            return nil
        }
        let maxAge = TimeInterval(maxAgeHours * 3600)
        guard Date().timeIntervalSince(timestamp) < maxAge else { return nil }
        return try? JSONDecoder().decode([DanmakuComment].self, from: data)
    }

    private func saveCommentsCache(key: String, comments: [DanmakuComment]) {
        if let data = try? JSONEncoder().encode(comments) {
            userDefaults.set(data, forKey: key + "_data")
            userDefaults.set(Date(), forKey: key + "_ts")
        }
    }
}
