//
//  DandanPlayClient.swift
//  PandaPlay
//
//  DandanPlay API client for danmaku (bullet comments).
//  API base: configurable, default https://api.dandanplay.com
//

import Foundation

// MARK: - Models

struct DanmakuComment: Codable, Identifiable {
    let cid: Int
    let p: String   // "timeMs,mode,color,timestamp,userId"
    let m: String   // content

    var id: Int { cid }

    var timeMs: Double {
        let parts = p.split(separator: ",")
        guard let first = parts.first, let time = Double(first) else { return 0 }
        return time * 1000 // seconds to ms
    }

    var mode: Int {
        let parts = p.split(separator: ",")
        guard parts.count > 1, let m = Int(parts[1]) else { return 1 }
        return m
    }

    var color: Int {
        let parts = p.split(separator: ",")
        guard parts.count > 2, let c = Int(parts[2]) else { return 16777215 }
        return c
    }

    var colorRGB: (r: Double, g: Double, b: Double) {
        let r = Double((color >> 16) & 0xFF) / 255.0
        let g = Double((color >> 8) & 0xFF) / 255.0
        let b = Double(color & 0xFF) / 255.0
        return (r, g, b)
    }
}

struct DanmakuMatchResult: Codable {
    let matches: [DanmakuMatch]?

    struct DanmakuMatch: Codable {
        let episodeId: String?
        let animeTitle: String?
        let episodeTitle: String?
        let season: Int?
        let episode: Int?
    }
}

struct DanmakuSearchResult: Codable {
    let animes: [DanmakuAnime]?

    struct DanmakuAnime: Codable, Identifiable {
        let animeId: Int?
        let animeTitle: String?
        let episodes: [DanmakuEpisode]?

        var id: Int { animeId ?? 0 }
    }

    struct DanmakuEpisode: Codable, Identifiable {
        let episodeId: Int?
        let episodeTitle: String?

        var id: Int { episodeId ?? 0 }
    }
}

struct DanmakuCommentResponse: Codable {
    let comments: [DanmakuComment]?
}

// MARK: - Client

class DandanPlayClient {
    static let shared = DandanPlayClient()

    private let session: URLSession
    private let baseURL: String

    init(baseURL: String = "https://danmu.940120.xyz:120") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Match by file info

    func match(fileName: String, fileHash: String? = nil, fileSize: Int64? = nil, videoDuration: Int? = nil) async throws -> DanmakuMatchResult {
        var body: [String: Any] = [
            "fileName": fileName,
            "matchMode": "hashAndFileName"
        ]
        if let fileHash { body["fileHash"] = fileHash }
        if let fileSize { body["fileSize"] = fileSize }
        if let videoDuration { body["videoDuration"] = videoDuration }

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let data = try await post("/api/v2/match", body: jsonData)
        return try JSONDecoder().decode(DanmakuMatchResult.self, from: data)
    }

    // MARK: - Search

    func searchEpisodes(keyword: String) async throws -> DanmakuSearchResult {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let data = try await get("/api/v2/search/episodes?keyword=\(encoded)")
        return try JSONDecoder().decode(DanmakuSearchResult.self, from: data)
    }

    func searchAnime(keyword: String) async throws -> DanmakuSearchResult {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let data = try await get("/api/v2/search/anime?keyword=\(encoded)")
        return try JSONDecoder().decode(DanmakuSearchResult.self, from: data)
    }

    // MARK: - Fetch Comments

    func fetchComments(episodeId: Int) async throws -> [DanmakuComment] {
        let data = try await get("/api/v2/comment/\(episodeId)")
        let response = try? JSONDecoder().decode(DanmakuCommentResponse.self, from: data)
        return response?.comments ?? []
    }

    // MARK: - HTTP Helpers

    private func get(_ endpoint: String) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw DanmakuError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("PandaPlay/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DanmakuError.invalidResponse
        }
        return data
    }

    private func post(_ endpoint: String, body: Data) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw DanmakuError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("PandaPlay/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DanmakuError.invalidResponse
        }
        return data
    }
}

// MARK: - Errors

enum DanmakuError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noMatch
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的弹幕 API 地址"
        case .invalidResponse: return "弹幕服务响应异常"
        case .noMatch: return "未找到匹配的弹幕"
        case .networkError(let msg): return "弹幕加载失败: \(msg)"
        }
    }
}
