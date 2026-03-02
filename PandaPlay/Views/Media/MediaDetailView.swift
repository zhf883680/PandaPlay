//
//  MediaDetailView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct MediaDetailView: View {
    let mediaItem: MediaItem

    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager

    @State private var fullItem: MediaItem?
    @State private var isLoading: Bool = true
    @State private var dynamicOverview: String = ""  // Dynamic overview from season/episode selection

    @State private var seasons: [MediaItem] = []
    @State private var selectedSeason: MediaItem?
    @State private var episodes: [MediaItem] = []
    @State private var isLoadingSeasons: Bool = false
    @State private var isLoadingEpisodes: Bool = false
    @State private var debugMessage: String = ""

    @State private var selectedEpisode: MediaItem?

    var displayItem: MediaItem {
        fullItem ?? mediaItem
    }

    // Display overview: use dynamic overview if available, otherwise fall back to series overview
    var displayOverview: String {
        if !dynamicOverview.isEmpty {
            return dynamicOverview
        }
        return displayItem.overview ?? ""
    }

    var backdropURL: URL? {
        guard let serverURL = serverManager.currentServer?.url else { return nil }
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        let endpoint = "emby/Items/\(displayItem.id)/Images/Backdrop"
        var components = URLComponents(string: url + endpoint)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: "1920"),
            URLQueryItem(name: "maxHeight", value: "1080"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(2)
                    Text("加载中...")
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
                .frame(height: 400)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Backdrop with image and overlay content
                    ZStack(alignment: .bottomLeading) {
                        // Background Image
                        AsyncImage(url: backdropURL) { phase in
                            switch phase {
                            case .empty, .failure:
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [Color.blue.opacity(0.3), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    .frame(height: 450)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 450)
                                    .clipped()
                                    .overlay(
                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.black.opacity(0.7), Color.black.opacity(0.3)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                            @unknown default:
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [Color.blue.opacity(0.3), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    .frame(height: 450)
                            }
                        }

                        VStack(alignment: .leading, spacing: 20) {
                            // Type Badge
                            if let type = displayItem.type {
                                Text(type == "Series" ? "电视剧" : type == "Movie" ? "电影" : type)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }

                            // Title
                            Text(displayItem.name ?? "")
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(.white)

                            // Metadata
                            HStack(spacing: 15) {
                                if let year = displayItem.productionYear {
                                    Text(String(year))
                                        .foregroundColor(.white.opacity(0.9))
                                }

                                if let genres = displayItem.genres, !genres.isEmpty {
                                    Text(genres.prefix(3).joined(separator: ", "))
                                        .foregroundColor(.white.opacity(0.9))
                                }

                                if let runtime = displayItem.runTimeTicks {
                                    let hours = runtime / 3600000000
                                    let minutes = (runtime % 3600000000) / 60000000
                                    if hours > 0 {
                                        Text("\(hours)小时\(minutes)分钟")
                                            .foregroundColor(.white.opacity(0.9))
                                    } else {
                                        Text("\(minutes) 分钟")
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }

                                if let rating = displayItem.communityRating {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                        Text(String(format: "%.1f", rating))
                                            .foregroundColor(.white.opacity(0.9))
                                            .font(.caption)
                                    }
                                }
                            }

                            // Play Button
                            if displayItem.type == "Movie" {
                                Button(action: {
                                    selectedEpisode = displayItem
                                }) {
                                    Label("播放", systemImage: "play.fill")
                                        .font(.title3)
                                        .bold()
                                        .frame(maxWidth: 200)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(80)
                    }
                    .clipped()

                    // Content Section
                    HStack(alignment: .top, spacing: 60) {
                        // Left: Season/Episode Selection
                        VStack(alignment: .leading, spacing: 40) {
                            if displayItem.type == "Series" {
                                SeasonEpisodeSelector(
                                    seriesId: displayItem.id,
                                    serverURL: serverManager.currentServer?.url ?? "",
                                    accessToken: authManager.accessToken ?? "",
                                    userId: authManager.userId ?? "",
                                    onEpisodeSelected: { episode in
                                        selectedEpisode = episode
                                    },
                                    onOverviewChanged: { overview in
                                        dynamicOverview = overview
                                    }
                                )
                                .environmentObject(serverManager)
                                .environmentObject(authManager)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Right: Overview (dynamic, changes with season/episode selection)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("简介")
                                .font(.title3)
                                .bold()
                            Text(displayOverview)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(5)
                        }
                        .frame(maxWidth: 500, alignment: .leading)
                    }
                    .padding(.horizontal, 80)
                    .padding(.top, 40)

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedEpisode) { episode in
            PlayerView(mediaItem: episode)
        }
        .task {
            await loadFullItemDetails()
        }
    }

    private func loadFullItemDetails() async {
        guard let serverURL = serverManager.currentServer?.url,
              let userId = authManager.userId,
              let accessToken = authManager.accessToken else {
            isLoading = false
            return
        }

        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        do {
            let item = try await client.getItem(itemId: mediaItem.id, userId: userId)
            await MainActor.run {
                self.fullItem = item
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Season/Episode Selector

struct SeasonEpisodeSelector: View {
    let seriesId: String
    let serverURL: String
    let accessToken: String
    let userId: String
    let onEpisodeSelected: (MediaItem) -> Void
    let onOverviewChanged: (String) -> Void

    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager

    @State private var seasons: [MediaItem] = []
    @State private var selectedSeason: MediaItem?
    @State private var selectedSeasonDetails: MediaItem?
    @State private var episodes: [MediaItem] = []
    @State private var selectedEpisode: MediaItem?
    @State private var isLoadingSeasons: Bool = true
    @State private var isLoadingEpisodes: Bool = false
    @State private var isLoadingSeasonDetails: Bool = false
    @State private var selectedEpisodeForPlay: MediaItem?
    @State private var debugMessage: String = ""

    // Current overview to display
    var currentOverview: String {
        if let episode = selectedEpisode, let overview = episode.overview, !overview.isEmpty {
            return overview
        } else if let seasonDetails = selectedSeasonDetails, let overview = seasonDetails.overview, !overview.isEmpty {
            return overview
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Seasons
            VStack(alignment: .leading, spacing: 15) {
                Text("选季")
                    .font(.title3)
                    .bold()

                if isLoadingSeasons {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if seasons.isEmpty {
                    VStack(spacing: 10) {
                        Text("没有找到季")
                            .foregroundColor(.secondary)
                        if !debugMessage.isEmpty {
                            Text(debugMessage)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(seasons) { season in
                                SeasonCard(
                                    season: season,
                                    isSelected: selectedSeason?.id == season.id,
                                    serverURL: serverManager.currentServer?.url ?? ""
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedSeason = season
                                        selectedEpisode = nil  // Clear episode selection when changing season
                                    }
                                    Task {
                                        await loadSeasonDetails(for: season.id)
                                        await loadEpisodes(for: season.id)
                                    }
                                }
                            }
                        }
                    }
                    .focusSection()
                }
            }

            // Episodes
            if let season = selectedSeason {
                VStack(alignment: .leading, spacing: 15) {
                    Text("选集")
                        .font(.title3)
                        .bold()

                    if isLoadingEpisodes {
                        ProgressView()
                    } else if episodes.isEmpty {
                        Text("没有找到集")
                            .foregroundColor(.secondary)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 15),
                            GridItem(.flexible(), spacing: 15),
                            GridItem(.flexible(), spacing: 15),
                            GridItem(.flexible(), spacing: 15)
                        ], spacing: 15) {
                            ForEach(episodes) { episode in
                                EpisodeCard(
                                    episode: episode,
                                    serverURL: serverManager.currentServer?.url ?? "",
                                    isSelected: selectedEpisode?.id == episode.id
                                )
                                .onTapGesture {
                                    selectedEpisode = episode
                                    onEpisodeSelected(episode)
                                    // Update overview when episode is selected
                                    onOverviewChanged(currentOverview)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            await loadSeasons()
        }
        .navigationDestination(item: $selectedEpisodeForPlay) { episode in
            PlayerView(mediaItem: episode)
        }
    }

    private func loadSeasons() async {
        print("🎬 [SeasonEpisodeSelector] loadSeasons called for seriesId: \(seriesId)")

        guard let serverURL = serverManager.currentServer?.url else {
            print("❌ [SeasonEpisodeSelector] No server URL")
            isLoadingSeasons = false
            debugMessage = "没有服务器URL"
            return
        }

        guard let userId = authManager.userId else {
            print("❌ [SeasonEpisodeSelector] No user ID")
            isLoadingSeasons = false
            debugMessage = "没有用户ID"
            return
        }

        guard let accessToken = authManager.accessToken else {
            print("❌ [SeasonEpisodeSelector] No access token")
            isLoadingSeasons = false
            debugMessage = "没有访问令牌"
            return
        }

        debugMessage = "正在加载: \(seriesId)"
        print("🔍 [SeasonEpisodeSelector] Creating EmbyClient with URL: \(serverURL)")
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        do {
            let seasonList = try await client.getSeasons(seriesId: seriesId, userId: userId)
            await MainActor.run {
                self.seasons = seasonList
                self.debugMessage = "加载到 \(seasonList.count) 个季"
                print("✅ [SeasonEpisodeSelector] Loaded \(seasonList.count) seasons")
                self.isLoadingSeasons = false
                if let firstSeason = seasonList.first {
                    self.selectedSeason = firstSeason
                    print("🎯 [SeasonEpisodeSelector] Selected first season: \(firstSeason.name ?? "unnamed")")
                    Task {
                        await loadSeasonDetails(for: firstSeason.id)
                        await loadEpisodes(for: firstSeason.id)
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.debugMessage = "加载失败: \(error.localizedDescription)"
                print("❌ [SeasonEpisodeSelector] Error loading seasons: \(error)")
                self.isLoadingSeasons = false
            }
        }
    }

    private func loadSeasonDetails(for seasonId: String) async {
        print("🎬 [SeasonEpisodeSelector] loadSeasonDetails for seasonId: \(seasonId)")

        guard let serverURL = serverManager.currentServer?.url,
              let userId = authManager.userId,
              let accessToken = authManager.accessToken else {
            return
        }

        isLoadingSeasonDetails = true
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        do {
            let details = try await client.getItem(itemId: seasonId, userId: userId)
            await MainActor.run {
                self.selectedSeasonDetails = details
                self.isLoadingSeasonDetails = false
                // Update overview when season is selected
                onOverviewChanged(currentOverview)
                print("✅ [SeasonEpisodeSelector] Loaded season details")
            }
        } catch {
            await MainActor.run {
                print("❌ [SeasonEpisodeSelector] Error loading season details: \(error)")
                self.isLoadingSeasonDetails = false
            }
        }
    }

    private func loadEpisodes(for seasonId: String) async {
        print("🎬 [SeasonEpisodeSelector] loadEpisodes called for seasonId: \(seasonId)")

        guard let serverURL = serverManager.currentServer?.url,
              let userId = authManager.userId,
              let accessToken = authManager.accessToken else {
            print("❌ [SeasonEpisodeSelector] Missing credentials for episodes")
            isLoadingEpisodes = false
            return
        }

        print("🔍 [SeasonEpisodeSelector] Loading episodes for season \(seasonId)")
        isLoadingEpisodes = true
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        do {
            let episodeList = try await client.getEpisodes(seasonId: seasonId, userId: userId)
            await MainActor.run {
                self.episodes = episodeList
                self.isLoadingEpisodes = false
                print("✅ [SeasonEpisodeSelector] Loaded \(episodeList.count) episodes")
            }
        } catch {
            await MainActor.run {
                print("❌ [SeasonEpisodeSelector] Error loading episodes: \(error)")
                self.isLoadingEpisodes = false
            }
        }
    }
}

// MARK: - Season Card

struct SeasonCard: View {
    let season: MediaItem
    let isSelected: Bool
    let serverURL: String

    @FocusState private var isFocused: Bool

    private var imageURL: URL? {
        guard let serverURL = serverURL.isEmpty ? nil : serverURL else { return nil }
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        let endpoint = "emby/Items/\(season.id)/Images/Primary"
        var components = URLComponents(string: url + endpoint)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: "300"),
            URLQueryItem(name: "maxHeight", value: "450"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty, .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 150, height: 225)
                        .overlay(
                            Image(systemName: "tv")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 225)
                        .clipped()
                @unknown default:
                    EmptyView()
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            Text(season.name ?? "第 \(season.indexNumber ?? 1) 季")
                .font(.caption)
                .foregroundColor(isFocused ? .primary : .secondary)
        }
        .frame(width: 150)
        .focusable()
        .focused($isFocused)
    }
}

// MARK: - Episode Card

struct EpisodeCard: View {
    let episode: MediaItem
    let serverURL: String
    let isSelected: Bool

    @FocusState private var isFocused: Bool

    private var imageURL: URL? {
        guard !serverURL.isEmpty else { return nil }
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        let endpoint = "emby/Items/\(episode.id)/Images/Primary"
        var components = URLComponents(string: url + endpoint)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: "300"),
            URLQueryItem(name: "maxHeight", value: "169"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty, .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(
                                Image(systemName: "play.circle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 110)
                            .clipped()
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : (isFocused ? Color.blue.opacity(0.5) : Color.clear), lineWidth: isSelected ? 3 : 2)
                )

                // Episode number badge
                if let index = episode.indexNumber {
                    Text("第 \(index) 集")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .foregroundColor(.white)
                        .padding(4)
                }
            }

            Text(episode.name ?? "第 \(episode.indexNumber ?? 1) 集")
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(isFocused ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isFocused ? Color.blue.opacity(0.1) : Color.clear)
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .focusable()
        .focused($isFocused)
    }
}

#Preview {
    NavigationView {
        MediaDetailView(mediaItem: MediaItem(
            id: "1",
            name: "示例电视剧",
            type: "Series",
            overview: "这是一个示例电视剧的描述。这是一个非常精彩的故事，讲述了一个关于冒险和成长的故事。主要角色经历了各种挑战和考验，最终成长为真正的英雄。",
            imageTags: nil,
            imageBlurHashes: nil,
            productionYear: 2024,
            genres: ["动作", "科幻", "冒险"],
            runTimeTicks: 3600000000,
            playbackPositionTicks: nil,
            userData: nil,
            mediaType: "Video",
            indexNumber: nil,
            parentIndexNumber: nil,
            seasonId: nil,
            seriesId: nil,
            seriesName: nil,
            communityRating: 8.5
        ))
        .environmentObject(ServerManager())
        .environmentObject(AuthManager())
    }
}
