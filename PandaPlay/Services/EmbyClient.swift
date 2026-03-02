//
//  EmbyClient.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation

class EmbyClient {
    private let baseURL: String
    private let session: URLSession
    private var accessToken: String?

    init(serverURL: String, accessToken: String? = nil) {
        // Normalize URL
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        self.baseURL = url

        // Store provided access token
        self.accessToken = accessToken

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Authentication

    func authenticate(username: String, password: String) async throws -> AuthenticationResponse {
        let endpoint = "emby/Users/AuthenticateByName"
        guard let url = URL(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add Authorization header
        let authHeader = "Emby Client=\"PandaPlay TV\", Device=\"Apple TV\", DeviceId=\"\(UUID().uuidString)\", Version=\"1.0.0\""
        request.setValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")

        let body: [String: Any] = [
            "Username": username,
            "Pw": password
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbyError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            throw EmbyError.authenticationFailed
        }

        let authResponse = try JSONDecoder().decode(AuthenticationResponse.self, from: data)

        // Store access token
        if let token = authResponse.accessToken {
            self.accessToken = token
        }

        return authResponse
    }

    // MARK: - Media Library

    func getItems(userId: String, filters: [String: String] = [:]) async throws -> [MediaItem] {
        let endpoint = "emby/Users/\(userId)/Items"
        guard var components = URLComponents(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }

        var queryItems: [URLQueryItem] = []
        for (key, value) in filters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw EmbyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw EmbyError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(MediaItemsResponse.self, from: data)
        return decoded.items ?? []
    }

    func getRecentItems(userId: String, limit: Int = 20) async throws -> [MediaItem] {
        return try await getItems(userId: userId, filters: [
            "SortBy": "DateCreated",
            "SortOrder": "Descending",
            "Limit": String(limit),
            "Recursive": "true"
        ])
    }

    func getResumeItems(userId: String, limit: Int = 20) async throws -> [MediaItem] {
        return try await getItems(userId: userId, filters: [
            "Filters": "IsResumable",
            "Limit": String(limit),
            "Recursive": "true"
        ])
    }

    // MARK: - Item Details

    func getItem(itemId: String, userId: String) async throws -> MediaItem {
        let endpoint = "emby/Users/\(userId)/Items/\(itemId)"
        guard let url = URL(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(MediaItem.self, from: data)
    }

    // MARK: - Seasons

    func getSeasons(seriesId: String, userId: String) async throws -> [MediaItem] {
        // Jellyfin supports both /Shows/ and /emby/Shows/
        let endpoint = "emby/Shows/\(seriesId)/Seasons?userId=\(userId)"
        guard let url = URL(string: baseURL + endpoint) else {
            print("❌ [EmbyClient] Invalid URL: \(baseURL)\(endpoint)")
            throw EmbyError.invalidURL
        }

        print("🔍 [EmbyClient] Fetching seasons from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("📡 [EmbyClient] Response status: \(httpResponse.statusCode)")
        }

        // Print response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 [EmbyClient] Response data (first 500 chars): \(jsonString.prefix(500))")
        }

        let decoded = try JSONDecoder().decode(MediaItemsResponse.self, from: data)
        print("✅ [EmbyClient] Decoded \(decoded.items?.count ?? 0) seasons")
        return decoded.items ?? []
    }

    // MARK: - Episodes

    func getEpisodes(seasonId: String, userId: String) async throws -> [MediaItem] {
        // Use the same format as the web UI
        let endpoint = "emby/Users/\(userId)/Items?UserId=\(userId)&ParentId=\(seasonId)&Recursive=true&IsFolder=false"
        guard let url = URL(string: baseURL + endpoint) else {
            print("❌ [EmbyClient] Invalid URL for episodes: \(baseURL)\(endpoint)")
            throw EmbyError.invalidURL
        }

        print("🔍 [EmbyClient] Fetching episodes from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("📡 [EmbyClient] Episodes response status: \(httpResponse.statusCode)")
        }

        let decoded = try JSONDecoder().decode(MediaItemsResponse.self, from: data)
        let items = decoded.items ?? []
        print("✅ [EmbyClient] Decoded \(items.count) episodes")

        // Sort by index number
        let sorted = items.sorted { ($0.indexNumber ?? 0) < ($1.indexNumber ?? 0) }
        if sorted.count != items.count {
            print("📊 [EmbyClient] Sorted episodes by index number")
        }

        return sorted
    }

    // MARK: - Playback Info

    func getPlaybackInfo(itemId: String, userId: String) async throws -> PlaybackInfoResponse {
        let endpoint = "emby/Items/\(itemId)/PlaybackInfo?userId=\(userId)"
        guard let url = URL(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(PlaybackInfoResponse.self, from: data)
    }

    // MARK: - Public Info

    func getServerInfo() async throws -> ServerInfo {
        let endpoint = "emby/System/Info/Public"
        guard let url = URL(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw EmbyError.invalidResponse
        }

        return try JSONDecoder().decode(ServerInfo.self, from: data)
    }

    // MARK: - Image URL Helper

    func getImageURL(itemId: String, imageType: String, maxWidth: Int = 500, maxHeight: Int = 750, quality: Int = 90) -> URL? {
        let endpoint = "emby/Items/\(itemId)/Images/\(imageType)"
        var components = URLComponents(string: baseURL + endpoint)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: String(maxWidth)),
            URLQueryItem(name: "maxHeight", value: String(maxHeight)),
            URLQueryItem(name: "quality", value: String(quality))
        ]
        return components?.url
    }

    // MARK: - Stream URL Helper

    func getStreamURL(itemId: String, userId: String, isStatic: Bool = false) -> URL? {
        // For direct stream / playback
        // 使用 stream 端点直接流式传输，设置 static=true 避免服务器转码
        let endpoint = "emby/Videos/\(itemId)/stream"
        var components = URLComponents(string: baseURL + endpoint)

        // 根据 Emby API 文档添加认证参数
        // static=true 表示直接流式传输原始文件，不转码（适用于 MKV 等格式）
        components?.queryItems = [
            URLQueryItem(name: "static", value: "true"),
            URLQueryItem(name: "api_key", value: accessToken ?? "")
        ]
        return components?.url
    }

    func getMasterM3U8URL(itemId: String, userId: String) -> URL? {
        // For HLS master playlist with transcoding support
        let endpoint = "emby/Videos/\(itemId)/master.m3u8"
        var components = URLComponents(string: baseURL + endpoint)
        components?.queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "api_key", value: accessToken ?? ""),
            // Force transcoding for better compatibility
            URLQueryItem(name: "MediaSourceId", value: itemId),
            // Video codec - use H264 for better tvOS compatibility
            URLQueryItem(name: "VideoCodec", value: "h264"),
            // Audio codec
            URLQueryItem(name: "AudioCodec", value: "aac"),
            // Max streaming bitrate
            URLQueryItem(name: "MaxStreamingBitrate", value: "40000000"),
            // Enable transcoding
            URLQueryItem(name: "TranscodingMaxAudioChannels", value: "6"),
            URLQueryItem(name: "RequireAvc", value: "true")
        ]
        return components?.url
    }
}

// MARK: - Models

struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let type: String?
    let overview: String?
    let imageTags: ImageTags?
    let imageBlurHashes: ImageBlurHashes?
    let productionYear: Int?
    let genres: [String]?
    let runTimeTicks: Int64?
    let playbackPositionTicks: Int64?
    let userData: UserData?
    let mediaType: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let seasonId: String?
    let seriesId: String?
    let seriesName: String?
    let communityRating: Double?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case overview = "Overview"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case productionYear = "ProductionYear"
        case genres = "Genres"
        case runTimeTicks = "RunTimeTicks"
        case playbackPositionTicks = "PlaybackPositionTicks"
        case userData = "UserData"
        case mediaType = "MediaType"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case seasonId = "SeasonId"
        case seriesId = "SeriesId"
        case seriesName = "SeriesName"
        case communityRating = "CommunityRating"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct UserData: Codable {
    let playbackPositionTicks: Int64?
    let played: Bool?
    let isFavorite: Bool?
    let unplayedItemCount: Int?
    let playCount: Int?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case played = "Played"
        case isFavorite = "IsFavorite"
        case unplayedItemCount = "UnplayedItemCount"
        case playCount = "PlayCount"
    }
}

struct ImageTags: Codable {
    let primary: String?
    let backdrop: String?
    let banner: String?

    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case banner = "Banner"
    }
}

struct ImageBlurHashes: Codable {
    let primary: [String: String]?
    let backdrop: [String: String]?

    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case backdrop = "Backdrop"
    }
}

struct MediaItemsResponse: Codable {
    let items: [MediaItem]?
    let totalRecordCount: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

struct ServerInfo: Codable {
    let productName: String?
    let version: String?
    let serverName: String?
}

struct AuthenticationResponse: Codable {
    let accessToken: String?
    let serverId: String?
    let user: EmbyUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case serverId = "ServerId"
        case user = "User"
    }
}

struct EmbyUser: Codable, Identifiable {
    let id: String
    let name: String
    let serverId: String?
    let hasPassword: Bool?
    let imageTags: ImageTags?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case hasPassword = "HasPassword"
        case imageTags = "ImageTags"
    }
}

struct PlaybackInfoResponse: Codable {
    let mediaSources: [MediaSource]?

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
    }
}

struct MediaSource: Codable {
    let supportsDirectPlay: Bool?
    let supportsDirectStream: Bool?
    let supportsTranscoding: Bool?
    let path: String?
    let container: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case path = "Path"
        case container = "Container"
        case type = "Type"
    }
}

// MARK: - Errors

enum EmbyError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .authenticationFailed:
            return "Authentication failed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        }
    }
}
