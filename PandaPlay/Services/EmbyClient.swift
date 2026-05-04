//
//  EmbyClient.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation

class EmbyClient {
    let baseURL: String
    private let session: URLSession
    private var accessToken: String?
    private let clientName = "PandaPlay"
    private let clientVersion = "1.0.0"
    private let deviceName = "PandaPlay"
    private let deviceId: String

    init(serverURL: String, accessToken: String? = nil) {
        // Normalize URL
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        self.baseURL = url

        // Store provided access token
        self.accessToken = accessToken
        let deviceIdKey = "emby_device_id"
        if let stored = UserDefaults.standard.string(forKey: deviceIdKey), !stored.isEmpty {
            self.deviceId = stored
        } else {
            let newId = UUID().uuidString
            self.deviceId = newId
            UserDefaults.standard.set(newId, forKey: deviceIdKey)
        }

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
        let authHeader = authorizationHeaderValue()
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

    func searchItems(userId: String, query: String, limit: Int = 50) async throws -> [MediaItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        return try await getItems(userId: userId, filters: [
            "Recursive": "true",
            "SearchTerm": normalizedQuery,
            "IncludeItemTypes": "Movie,Series,Episode",
            "Limit": String(limit),
            "Fields": "Overview,Genres,CommunityRating,ProductionYear,RunTimeTicks,UserData",
            "SortBy": "SortName",
            "SortOrder": "Ascending"
        ])
    }

    func getResumeItems(userId: String, limit: Int = 20) async throws -> [MediaItem] {
        let endpoint = "emby/Users/\(userId)/Items/Resume"
        guard let baseComponents = URLComponents(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }

        let strategies: [[URLQueryItem]] = [
            // Strategy 1: mimic Web query as close as possible.
            [
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "MediaTypes", value: "Video"),
                URLQueryItem(name: "ImageTypeLimit", value: "1"),
                URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb"),
                URLQueryItem(name: "Limit", value: String(limit)),
                URLQueryItem(name: "Fields", value: "BasicSyncInfo,CanDelete,CanDownload,PrimaryImageAspectRatio,ProgramPrimaryImageAspectRatio,ProductionYear,Status,EndDate")
            ],
            // Strategy 2: keep Resume endpoint, remove MediaTypes.
            [
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "ImageTypeLimit", value: "1"),
                URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb"),
                URLQueryItem(name: "Limit", value: String(limit)),
                URLQueryItem(name: "Fields", value: "BasicSyncInfo,CanDelete,CanDownload,PrimaryImageAspectRatio,ProgramPrimaryImageAspectRatio,ProductionYear,Status,EndDate")
            ],
            // Strategy 3: minimal Resume query.
            [
                URLQueryItem(name: "Limit", value: String(limit)),
                URLQueryItem(name: "Recursive", value: "true")
            ]
        ]

        for (_, queryItems) in strategies.enumerated() {
            var components = baseComponents
            var requestQueryItems = queryItems
            requestQueryItems.append(contentsOf: [
                URLQueryItem(name: "X-Emby-Client", value: clientName),
                URLQueryItem(name: "X-Emby-Device-Name", value: deviceName),
                URLQueryItem(name: "X-Emby-Device-Id", value: deviceId),
                URLQueryItem(name: "X-Emby-Client-Version", value: clientVersion),
                URLQueryItem(name: "X-Emby-Language", value: "zh-cn")
            ])
            if let token = accessToken, !token.isEmpty {
                requestQueryItems.append(URLQueryItem(name: "X-Emby-Token", value: token))
            }
            components.queryItems = requestQueryItems

            guard let url = components.url else { continue }
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let token = accessToken {
                request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
            }

            do {
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    continue
                }

                let decoded = try JSONDecoder().decode(MediaItemsResponse.self, from: data)
                let resumeItems = decoded.items ?? []
                if !resumeItems.isEmpty {
                    return resumeItems
                }
            } catch {
                continue
            }
        }

        // Fallback for servers that do not fully support /Items/Resume.
        if let resumableItems = try? await getItems(userId: userId, filters: [
            "Filters": "IsResumable",
            "Limit": String(limit),
            "Recursive": "true",
            "IncludeItemTypes": "Movie,Episode",
            "Fields": "Overview,Genres,CommunityRating,ProductionYear,RunTimeTicks,UserData",
            "SortBy": "DatePlayed",
            "SortOrder": "Descending"
        ]), !resumableItems.isEmpty {
            return resumableItems
        }

        // Second fallback to maximize compatibility.
        let fallback2 = try await getItems(userId: userId, filters: [
            "IsResumable": "true",
            "Limit": String(limit),
            "Recursive": "true",
            "IncludeItemTypes": "Movie,Episode",
            "Fields": "Overview,Genres,CommunityRating,ProductionYear,RunTimeTicks,UserData",
            "SortBy": "DatePlayed",
            "SortOrder": "Descending"
        ])
        return fallback2
    }

    // MARK: - Item Details

    func getItem(itemId: String, userId: String) async throws -> MediaItem {
        let endpoint = "emby/Users/\(userId)/Items/\(itemId)"
        guard var components = URLComponents(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "Fields", value: "Overview,Genres,CommunityRating,ProductionYear,RunTimeTicks,People,Studios,ExternalUrls,ProviderIds,Taglines,RemoteTrailers,OfficialRating,CanDownload,CriticRating,ChildCount,Status")
        ]

        guard let url = components.url else {
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
            throw EmbyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }

        let (data, _) = try await session.data(for: request)

        let decoded = try JSONDecoder().decode(MediaItemsResponse.self, from: data)
        return decoded.items ?? []
    }

    // MARK: - Episodes

    func getEpisodes(seasonId: String, userId: String) async throws -> [MediaItem] {
        // Use the same format as the web UI
        let endpoint = "emby/Users/\(userId)/Items?UserId=\(userId)&ParentId=\(seasonId)&Recursive=true&IsFolder=false&Fields=Overview,RunTimeTicks"
        guard let url = URL(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }

        let (data, _) = try await session.data(for: request)

        let decoded = try JSONDecoder().decode(MediaItemsResponse.self, from: data)
        let items = decoded.items ?? []

        // Sort by index number
        let sorted = items.sorted { ($0.indexNumber ?? 0) < ($1.indexNumber ?? 0) }

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

    // MARK: - Playback Check-ins

    func reportPlaybackStarted(
        itemId: String,
        positionTicks: Int64?,
        runTimeTicks: Int64?,
        playSessionId: String,
        sessionId: String?
    ) async throws {
        var payload: [String: Any] = [
            "ItemId": itemId,
            "CanSeek": true,
            "IsPaused": false,
            "PlayMethod": "DirectPlay",
            "PlaySessionId": playSessionId,
            "MediaSourceId": itemId
        ]

        if let positionTicks {
            payload["PositionTicks"] = positionTicks
        }
        if let runTimeTicks {
            payload["RunTimeTicks"] = runTimeTicks
        }
        if let sessionId, !sessionId.isEmpty {
            payload["SessionId"] = sessionId
        }

        try await postPlaybackCheckIn(endpoint: "emby/Sessions/Playing", payload: payload)
    }

    func reportPlaybackProgress(
        itemId: String,
        positionTicks: Int64,
        runTimeTicks: Int64?,
        isPaused: Bool,
        playSessionId: String,
        sessionId: String?
    ) async throws {
        var payload: [String: Any] = [
            "ItemId": itemId,
            "CanSeek": true,
            "IsPaused": isPaused,
            "PlayMethod": "DirectPlay",
            "PositionTicks": positionTicks,
            "PlaySessionId": playSessionId,
            "MediaSourceId": itemId
        ]

        if let runTimeTicks {
            payload["RunTimeTicks"] = runTimeTicks
        }
        if let sessionId, !sessionId.isEmpty {
            payload["SessionId"] = sessionId
        }

        try await postPlaybackCheckIn(endpoint: "emby/Sessions/Playing/Progress", payload: payload)
    }

    func reportPlaybackStopped(
        itemId: String,
        positionTicks: Int64,
        playSessionId: String,
        sessionId: String?
    ) async throws {
        var payload: [String: Any] = [
            "ItemId": itemId,
            "PositionTicks": positionTicks,
            "PlaySessionId": playSessionId,
            "MediaSourceId": itemId,
            "Failed": false
        ]
        if let sessionId, !sessionId.isEmpty {
            payload["SessionId"] = sessionId
        }

        try await postPlaybackCheckIn(endpoint: "emby/Sessions/Playing/Stopped", payload: payload)
    }

    func getCurrentSessionId(userId: String?) async -> String? {
        let endpoint = "emby/Sessions"
        guard var components = URLComponents(string: baseURL + endpoint) else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "DeviceId", value: deviceId)
        ]

        guard let url = components.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorizationHeaderValue(), forHTTPHeaderField: "X-Emby-Authorization")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            let sessions = try JSONDecoder().decode([SessionInfo].self, from: data)
            if let userId, !userId.isEmpty {
                return sessions.first(where: { $0.userId == userId })?.id ?? sessions.first?.id
            }
            return sessions.first?.id
        } catch {
            return nil
        }
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

    func getStreamURL(itemId: String, userId: String, isStatic: Bool = false, mediaSourceId: String? = nil) -> URL? {
        // For direct stream / playback
        let endpoint = "emby/Videos/\(itemId)/stream"
        var components = URLComponents(string: baseURL + endpoint)

        var queryItems = [
            URLQueryItem(name: "static", value: isStatic ? "true" : "false"),
            URLQueryItem(name: "api_key", value: accessToken ?? "")
        ]
        if let mediaSourceId {
            queryItems.append(URLQueryItem(name: "MediaSourceId", value: mediaSourceId))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    func getMasterM3U8URL(itemId: String, userId: String, maxBitrate: Int? = nil) -> URL? {
        // For HLS master playlist with transcoding support
        let endpoint = "emby/Videos/\(itemId)/master.m3u8"
        var components = URLComponents(string: baseURL + endpoint)
        var queryItems = [
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "api_key", value: accessToken ?? ""),
            URLQueryItem(name: "MediaSourceId", value: itemId),
            URLQueryItem(name: "VideoCodec", value: "h264"),
            URLQueryItem(name: "AudioCodec", value: "aac"),
            URLQueryItem(name: "MaxStreamingBitrate", value: String(maxBitrate ?? 40000000)),
            URLQueryItem(name: "TranscodingMaxAudioChannels", value: "6"),
            URLQueryItem(name: "RequireAvc", value: "true")
        ]
        components?.queryItems = queryItems
        return components?.url
    }

    // MARK: - Favorites

    func setFavorite(itemId: String, userId: String, isFavorite: Bool) async throws {
        let endpoint = "emby/Users/\(userId)/FavoriteItems/\(itemId)"
        try await sendEmptyRequest(endpoint: endpoint, method: isFavorite ? "POST" : "DELETE")
    }

    // MARK: - Played Status

    func setPlayed(itemId: String, userId: String, isPlayed: Bool) async throws {
        let endpoint = "emby/Users/\(userId)/PlayedItems/\(itemId)"
        try await sendEmptyRequest(endpoint: endpoint, method: isPlayed ? "POST" : "DELETE")
    }

    // MARK: - Similar Items

    func getSimilarItems(itemId: String, userId: String, limit: Int = 12) async throws -> [MediaItem] {
        let endpoint = "emby/Items/\(itemId)/Similar?UserId=\(userId)&Limit=\(limit)&Fields=Overview,Genres,CommunityRating,ProductionYear"
        guard let url = URL(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }
        let (data, _) = try await session.data(for: request)
        struct SimilarResponse: Codable {
            let items: [MediaItem]?
            enum CodingKeys: String, CodingKey { case items = "Items" }
        }
        return (try? JSONDecoder().decode(SimilarResponse.self, from: data).items) ?? []
    }

    // MARK: - Next Up

    func getNextUp(userId: String, limit: Int = 20) async throws -> [MediaItem] {
        let endpoint = "emby/Shows/NextUp?UserId=\(userId)&Limit=\(limit)&Fields=Overview,Genres,CommunityRating,ProductionYear"
        guard let url = URL(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }
        let (data, _) = try await session.data(for: request)
        return (try? JSONDecoder().decode(MediaItemsResponse.self, from: data).items) ?? []
    }

    // MARK: - User Views (Libraries)

    func getUserViews(userId: String) async throws -> [MediaItem] {
        let endpoint = "emby/Users/\(userId)/Views"
        guard let url = URL(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }
        let (data, _) = try await session.data(for: request)
        return (try? JSONDecoder().decode(MediaItemsResponse.self, from: data).items) ?? []
    }

    // MARK: - Authenticated System Info

    func getSystemInfo() async throws -> ServerInfo {
        let endpoint = "emby/System/Info"
        guard let url = URL(string: baseURL + endpoint) else {
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
        return try JSONDecoder().decode(ServerInfo.self, from: data)
    }
}

private extension EmbyClient {
    func sendEmptyRequest(endpoint: String, method: String) async throws {
        guard let url = URL(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }
        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw EmbyError.invalidResponse
        }
    }

    func fetchMediaItems(with request: URLRequest) async throws -> [MediaItem] {
        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw EmbyError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(MediaItemsResponse.self, from: data)
        return decoded.items ?? []
    }

    func postPlaybackCheckIn(endpoint: String, payload: [String: Any]) async throws {
        guard var components = URLComponents(string: baseURL + endpoint) else {
            throw EmbyError.invalidURL
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "X-Emby-Client", value: clientName),
            URLQueryItem(name: "X-Emby-Device-Name", value: deviceName),
            URLQueryItem(name: "X-Emby-Device-Id", value: deviceId),
            URLQueryItem(name: "X-Emby-Client-Version", value: clientVersion),
            URLQueryItem(name: "X-Emby-Language", value: "zh-cn")
        ]
        if let token = accessToken, !token.isEmpty {
            queryItems.append(URLQueryItem(name: "X-Emby-Token", value: token))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw EmbyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorizationHeaderValue(), forHTTPHeaderField: "X-Emby-Authorization")
        if let token = accessToken {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            #if DEBUG
            print("❌ [EmbyClient] Playback check-in failed endpoint=\(endpoint) status=\(httpResponse.statusCode)")
            #endif
            throw EmbyError.invalidResponse
        }
    }

    func authorizationHeaderValue() -> String {
        "Emby Client=\"\(clientName)\", Device=\"\(deviceName)\", DeviceId=\"\(deviceId)\", Version=\"\(clientVersion)\""
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
    let taglines: [String]?
    let officialRating: String?
    let people: [MediaPersonInfo]?
    let studios: [MediaStudioInfo]?
    let externalUrls: [MediaExternalUrlInfo]?
    let remoteTrailers: [RemoteTrailerInfo]?
    let providerIds: [String: String]?
    let canDownload: Bool?
    let criticRating: Int?
    let childCount: Int?
    let status: String?
    let collectionType: String?

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
        case taglines = "Taglines"
        case officialRating = "OfficialRating"
        case people = "People"
        case studios = "Studios"
        case externalUrls = "ExternalUrls"
        case remoteTrailers = "RemoteTrailers"
        case providerIds = "ProviderIds"
        case canDownload = "CanDownload"
        case criticRating = "CriticRating"
        case childCount = "ChildCount"
        case status = "Status"
        case collectionType = "CollectionType"
    }

    init(id: String, name: String? = nil, type: String? = nil, overview: String? = nil,
         imageTags: ImageTags? = nil, imageBlurHashes: ImageBlurHashes? = nil,
         productionYear: Int? = nil, genres: [String]? = nil, runTimeTicks: Int64? = nil,
         playbackPositionTicks: Int64? = nil, userData: UserData? = nil,
         mediaType: String? = nil, indexNumber: Int? = nil, parentIndexNumber: Int? = nil,
         seasonId: String? = nil, seriesId: String? = nil, seriesName: String? = nil,
         communityRating: Double? = nil, taglines: [String]? = nil,
         officialRating: String? = nil, people: [MediaPersonInfo]? = nil,
         studios: [MediaStudioInfo]? = nil, externalUrls: [MediaExternalUrlInfo]? = nil,
         remoteTrailers: [RemoteTrailerInfo]? = nil, providerIds: [String: String]? = nil,
         canDownload: Bool? = nil, criticRating: Int? = nil, childCount: Int? = nil,
         status: String? = nil, collectionType: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.overview = overview
        self.imageTags = imageTags
        self.imageBlurHashes = imageBlurHashes
        self.productionYear = productionYear
        self.genres = genres
        self.runTimeTicks = runTimeTicks
        self.playbackPositionTicks = playbackPositionTicks
        self.userData = userData
        self.mediaType = mediaType
        self.indexNumber = indexNumber
        self.parentIndexNumber = parentIndexNumber
        self.seasonId = seasonId
        self.seriesId = seriesId
        self.seriesName = seriesName
        self.communityRating = communityRating
        self.taglines = taglines
        self.officialRating = officialRating
        self.people = people
        self.studios = studios
        self.externalUrls = externalUrls
        self.remoteTrailers = remoteTrailers
        self.providerIds = providerIds
        self.canDownload = canDownload
        self.criticRating = criticRating
        self.childCount = childCount
        self.status = status
        self.collectionType = collectionType
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
    let operatingSystem: String?

    enum CodingKeys: String, CodingKey {
        case productName = "ProductName"
        case version = "Version"
        case serverName = "ServerName"
        case operatingSystem = "OperatingSystem"
    }
}

private struct SessionInfo: Codable {
    let id: String?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case userId = "UserId"
    }
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
    let id: String?
    let supportsDirectPlay: Bool?
    let supportsDirectStream: Bool?
    let supportsTranscoding: Bool?
    let path: String?
    let container: String?
    let type: String?
    let directStreamUrl: String?
    let transcodingUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case path = "Path"
        case container = "Container"
        case type = "Type"
        case directStreamUrl = "DirectStreamUrl"
        case transcodingUrl = "TranscodingUrl"
    }
}

// MARK: - Supporting Models

struct MediaPersonInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let role: String?
    let type: String?
    let primaryImageTag: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case role = "Role"
        case type = "Type"
        case primaryImageTag = "PrimaryImageTag"
    }
}

struct MediaStudioInfo: Codable, Hashable {
    let name: String
    let id: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
    }
}

struct MediaExternalUrlInfo: Codable {
    let name: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case url = "Url"
    }
}

struct RemoteTrailerInfo: Codable {
    let url: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case url = "Url"
        case name = "Name"
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
