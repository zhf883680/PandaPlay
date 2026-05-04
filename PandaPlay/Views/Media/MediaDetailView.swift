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
    @EnvironmentObject var toastManager: ToastManager

    @State private var fullItem: MediaItem?
    @State private var isLoading: Bool = true
    @State private var dynamicOverview: String = ""

    @State private var seasons: [MediaItem] = []
    @State private var selectedSeason: MediaItem?
    @State private var episodes: [MediaItem] = []
    @State private var isLoadingSeasons: Bool = false
    @State private var isLoadingEpisodes: Bool = false
    @State private var debugMessage: String = ""

    @State private var selectedEpisode: MediaItem?
    @State private var selectedDetailDestination: HomeNavigationDestination?
    @State private var isFavorite: Bool = false
    @State private var isPlayed: Bool = false
    @State private var similarItems: [MediaItem] = []

    var displayItem: MediaItem {
        fullItem ?? mediaItem
    }

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

    private var horizontalPadding: CGFloat {
        DeviceType.current == .iPhone ? 16 : (DeviceType.current == .iPad ? 40 : 80)
    }

    private var backdropHeight: CGFloat {
        DeviceType.current == .iPhone ? 220 : (DeviceType.current == .iPad ? 350 : 450)
    }

    private var contentSpacing: CGFloat {
        DeviceType.current == .iPhone ? 16 : (DeviceType.current == .iPad ? 30 : 40)
    }

    private var itemSpacing: CGFloat {
        DeviceType.current == .iPhone ? 12 : (DeviceType.current == .iPad ? 20 : 30)
    }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(DeviceType.current == .iPhone ? 1.2 : 2)
                    Text("加载中...")
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                }
                .frame(height: backdropHeight)
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
                                    .frame(height: backdropHeight)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: backdropHeight)
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
                                    .frame(height: backdropHeight)
                            }
                        }

                        VStack(alignment: .leading, spacing: DeviceType.current == .iPhone ? 8 : 20) {
                            // Type Badge
                            if let type = displayItem.type {
                                Text(type == "Series" ? "电视剧" : type == "Movie" ? "电影" : type)
                                    .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                                    .padding(.horizontal, DeviceType.current == .iPhone ? 8 : 12)
                                    .padding(.vertical, DeviceType.current == .iPhone ? 3 : 6)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.white)
                            }

                            // Title
                            Text(displayItem.name ?? "")
                                .font(DeviceType.current == .iPhone ? .title3 : .largeTitle)
                                .bold()
                                .foregroundColor(.white)
                                .lineLimit(2)

                            // Tagline
                            if let taglines = displayItem.taglines, let tagline = taglines.first, !tagline.isEmpty {
                                Text(tagline)
                                    .italic()
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(DeviceType.current == .iPhone ? .caption : .body)
                            }

                            // Metadata
                            HStack(spacing: DeviceType.current == .iPhone ? 8 : 15) {
                                if let year = displayItem.productionYear {
                                    Text(String(year))
                                        .foregroundColor(.white.opacity(0.9))
                                        .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                                }

                                if let genres = displayItem.genres, !genres.isEmpty {
                                    Text(genres.prefix(2).joined(separator: ", "))
                                        .foregroundColor(.white.opacity(0.9))
                                        .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                                        .lineLimit(1)
                                }

                                if let runtime = displayItem.runTimeTicks {
                                    let hours = runtime / 3600000000
                                    let minutes = (runtime % 3600000000) / 60000000
                                    if hours > 0 {
                                        Text("\(hours)小时\(minutes)分钟")
                                            .foregroundColor(.white.opacity(0.9))
                                            .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                                    } else {
                                        Text("\(minutes) 分钟")
                                            .foregroundColor(.white.opacity(0.9))
                                            .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                                    }
                                }

                                if let rating = displayItem.communityRating {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                                        Text(String(format: "%.1f", rating))
                                            .foregroundColor(.white.opacity(0.9))
                                            .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                                    }
                                }

                                if let rating = displayItem.officialRating {
                                    Text(rating)
                                        .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(4)
                                        .foregroundColor(.white)
                                }
                            }

                            // Action Buttons
                            HStack(spacing: DeviceType.current == .iPhone ? 8 : 12) {
                                if displayItem.type == "Movie" {
                                    Button(action: {
                                        selectedEpisode = displayItem
                                    }) {
                                        Label("播放", systemImage: "play.fill")
                                            .font(DeviceType.current == .iPhone ? .subheadline : .title3)
                                            .bold()
                                            .frame(maxWidth: DeviceType.current == .iPhone ? 120 : 160)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }

                                Button {
                                    Task { await toggleFavorite() }
                                } label: {
                                    Label(isFavorite ? "已收藏" : "收藏",
                                          systemImage: isFavorite ? "heart.fill" : "heart")
                                        .font(DeviceType.current == .iPhone ? .caption : .callout)
                                }
                                .tint(isFavorite ? .pink : .blue)
                                .buttonStyle(.bordered)

                                Button {
                                    Task { await togglePlayed() }
                                } label: {
                                    Label(isPlayed ? "已看" : "标记已看",
                                          systemImage: isPlayed ? "checkmark.circle.fill" : "checkmark.circle")
                                        .font(DeviceType.current == .iPhone ? .caption : .callout)
                                }
                                .tint(isPlayed ? .green : .blue)
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(DeviceType.current == .iPhone ? 16 : 80)
                    }
                    .clipped()

                    // Content Section
                    if DeviceType.current == .iPhone {
                        // iPhone: Vertical layout
                        VStack(alignment: .leading, spacing: contentSpacing) {
                            // Overview
                            if !displayOverview.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("简介")
                                        .font(.headline)
                                    Text(displayOverview)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineSpacing(4)
                                }
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, contentSpacing)
                            }

                            // Season/Episode Selection
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

                            // Cast
                            castSection

                            // Similar
                            similarSection
                        }
                    } else {
                        // iPad/tvOS: Horizontal layout
                        HStack(alignment: .top, spacing: 60) {
                            // Left: Season/Episode Selection
                            VStack(alignment: .leading, spacing: 40) {
                                if !displayOverview.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("简介")
                                            .font(.title3)
                                            .bold()
                                        Text(displayOverview)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .lineSpacing(5)
                                    }
                                }

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

                            // Right: Cast + Similar
                            VStack(alignment: .leading, spacing: contentSpacing) {
                                castSection
                                similarSection
                            }
                            .frame(maxWidth: 500, alignment: .leading)
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, contentSpacing)
                    }

                    Spacer(minLength: DeviceType.current == .iPhone ? 30 : 100)
                }
            }
        }
        .navigationDestination(item: $selectedEpisode) { episode in
            PlayerView(mediaItem: episode)
        }
        .navigationDestination(item: $selectedDetailDestination) { destination in
            switch destination {
            case .detail(let item):
                MediaDetailView(mediaItem: item)
            case .player(let item):
                PlayerView(mediaItem: item)
            case .library:
                EmptyView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ServerSwitcher()
            }
        }
        .task {
            await loadFullItemDetails()
        }
    }

    // MARK: - Cast Section

    @ViewBuilder
    private var castSection: some View {
        if let people = displayItem.people, !people.isEmpty {
            let displayPeople = people.filter { person in
                guard let type = person.type else { return true }
                return type == "Actor" || type == "Director" || type == "Writer"
            }.prefix(20)

            if !displayPeople.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("演职人员")
                        .font(.headline)
                        .padding(.horizontal, horizontalPadding)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: itemSpacing) {
                            ForEach(Array(displayPeople)) { person in
                                PersonCard(person: person, serverURL: serverManager.currentServer?.url ?? "")
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                    #if !os(iOS)
                    .focusSection()
                    #endif
                }
            }
        }
    }

    // MARK: - Similar Section

    @ViewBuilder
    private var similarSection: some View {
        if !similarItems.isEmpty {
            MediaRow(
                title: "相似推荐",
                items: similarItems,
                serverURL: serverManager.currentServer?.url ?? "",
                onSelect: { item in
                    selectedDetailDestination = .detail(item)
                }
            )
        }
    }

    // MARK: - Actions

    private func loadFullItemDetails() async {
        guard let serverURL = serverManager.currentServer?.url,
              let userId = authManager.userId,
              let accessToken = authManager.accessToken else {
            isLoading = false
            return
        }

        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        do {
            async let item = client.getItem(itemId: mediaItem.id, userId: userId)
            async let similarResult = client.getSimilarItems(itemId: mediaItem.id, userId: userId, limit: 12)

            let fullItem = try await item
            let similar = (try? await similarResult) ?? []

            await MainActor.run {
                self.fullItem = fullItem
                self.isFavorite = fullItem.userData?.isFavorite ?? false
                self.isPlayed = fullItem.userData?.played ?? false
                self.similarItems = similar
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func toggleFavorite() async {
        guard let serverURL = serverManager.currentServer?.url,
              let userId = authManager.userId,
              let accessToken = authManager.accessToken else { return }
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        let newValue = !isFavorite
        do {
            try await client.setFavorite(itemId: displayItem.id, userId: userId, isFavorite: newValue)
            isFavorite = newValue
        } catch {
            toastManager.show("操作失败", type: .error)
        }
    }

    private func togglePlayed() async {
        guard let serverURL = serverManager.currentServer?.url,
              let userId = authManager.userId,
              let accessToken = authManager.accessToken else { return }
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        let newValue = !isPlayed
        do {
            try await client.setPlayed(itemId: displayItem.id, userId: userId, isPlayed: newValue)
            isPlayed = newValue
        } catch {
            toastManager.show("操作失败", type: .error)
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

    private var horizontalPadding: CGFloat {
        DeviceType.current == .iPhone ? 16 : (DeviceType.current == .iPad ? 20 : 30)
    }

    private var gridColumns: Int {
        DeviceType.current == .iPhone ? 3 : (DeviceType.current == .iPad ? 4 : 4)
    }

    var currentOverview: String {
        if let episode = selectedEpisode, let overview = episode.overview, !overview.isEmpty {
            return overview
        } else if let seasonDetails = selectedSeasonDetails, let overview = seasonDetails.overview, !overview.isEmpty {
            return overview
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DeviceType.current == .iPhone ? 16 : 30) {
            // Seasons
            VStack(alignment: .leading, spacing: DeviceType.current == .iPhone ? 8 : 15) {
                Text("选季")
                    .font(DeviceType.current == .iPhone ? .subheadline : .title3)
                    .bold()

                if isLoadingSeasons {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if seasons.isEmpty {
                    VStack(spacing: 6) {
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
                        HStack(spacing: DeviceType.current == .iPhone ? 10 : 15) {
                            ForEach(seasons) { season in
                                SeasonCard(
                                    season: season,
                                    isSelected: selectedSeason?.id == season.id,
                                    serverURL: serverManager.currentServer?.url ?? ""
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedSeason = season
                                        selectedEpisode = nil
                                    }
                                    Task {
                                        await loadSeasonDetails(for: season.id)
                                        await loadEpisodes(for: season.id)
                                    }
                                }
                            }
                        }
                    }
                    #if !os(iOS)
                    .focusSection()
                    #endif
                }
            }
            .padding(.horizontal, horizontalPadding)

            // Episodes
            if selectedSeason != nil {
                VStack(alignment: .leading, spacing: DeviceType.current == .iPhone ? 8 : 15) {
                    Text("选集")
                        .font(DeviceType.current == .iPhone ? .subheadline : .title3)
                        .bold()

                    if isLoadingEpisodes {
                        ProgressView()
                    } else if episodes.isEmpty {
                        Text("没有找到集")
                            .foregroundColor(.secondary)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DeviceType.current == .iPhone ? 8 : 15), count: gridColumns), spacing: DeviceType.current == .iPhone ? 8 : 15) {
                            ForEach(episodes) { episode in
                                EpisodeCard(
                                    episode: episode,
                                    serverURL: serverManager.currentServer?.url ?? "",
                                    isSelected: selectedEpisode?.id == episode.id
                                )
                                .onTapGesture {
                                    selectedEpisode = episode
                                    onEpisodeSelected(episode)
                                    onOverviewChanged(currentOverview)
                                    // Fetch full episode details for overview
                                    Task { await loadEpisodeDetails(for: episode.id) }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
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
        guard let serverURL = serverManager.currentServer?.url else {
            isLoadingSeasons = false
            debugMessage = "没有服务器URL"
            return
        }

        guard let userId = authManager.userId else {
            isLoadingSeasons = false
            debugMessage = "没有用户ID"
            return
        }

        guard let accessToken = authManager.accessToken else {
            isLoadingSeasons = false
            debugMessage = "没有访问令牌"
            return
        }

        debugMessage = "正在加载: \(seriesId)"
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        do {
            let seasonList = try await client.getSeasons(seriesId: seriesId, userId: userId)
            await MainActor.run {
                self.seasons = seasonList
                self.debugMessage = "加载到 \(seasonList.count) 个季"
                self.isLoadingSeasons = false
                if let firstSeason = seasonList.first {
                    self.selectedSeason = firstSeason
                    Task {
                        await loadSeasonDetails(for: firstSeason.id)
                        await loadEpisodes(for: firstSeason.id)
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.debugMessage = "加载失败: \(error.localizedDescription)"
                self.isLoadingSeasons = false
            }
        }
    }

    private func loadSeasonDetails(for seasonId: String) async {
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
                onOverviewChanged(currentOverview)
            }
        } catch {
            await MainActor.run {
                self.isLoadingSeasonDetails = false
            }
        }
    }

    private func loadEpisodes(for seasonId: String) async {
        guard let serverURL = serverManager.currentServer?.url,
              let userId = authManager.userId,
              let accessToken = authManager.accessToken else {
            isLoadingEpisodes = false
            return
        }

        isLoadingEpisodes = true
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        do {
            let episodeList = try await client.getEpisodes(seasonId: seasonId, userId: userId)
            await MainActor.run {
                self.episodes = episodeList
                self.isLoadingEpisodes = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingEpisodes = false
            }
        }
    }

    private func loadEpisodeDetails(for episodeId: String) async {
        guard let serverURL = serverManager.currentServer?.url,
              let userId = authManager.userId,
              let accessToken = authManager.accessToken else { return }
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        do {
            let details = try await client.getItem(itemId: episodeId, userId: userId)
            await MainActor.run {
                if let overview = details.overview, !overview.isEmpty {
                    onOverviewChanged(overview)
                }
                if selectedEpisode?.id == episodeId {
                    selectedEpisode = details
                }
            }
        } catch {
            // Silently fail - overview will remain from season or empty
        }
    }
}

// MARK: - Season Card

struct SeasonCard: View {
    let season: MediaItem
    let isSelected: Bool
    let serverURL: String

    #if !os(iOS)
    @FocusState private var isFocused: Bool
    #endif

    private var cardWidth: CGFloat {
        DeviceType.current == .iPhone ? 80 : (DeviceType.current == .iPad ? 120 : 150)
    }

    private var cardHeight: CGFloat {
        DeviceType.current == .iPhone ? 120 : (DeviceType.current == .iPad ? 180 : 225)
    }

    private var imageWidth: CGFloat {
        DeviceType.current == .iPhone ? 80 : (DeviceType.current == .iPad ? 120 : 150)
    }

    private var imageHeight: CGFloat {
        DeviceType.current == .iPhone ? 100 : (DeviceType.current == .iPad ? 150 : 200)
    }

    private var imageURL: URL? {
        guard let serverURL = serverURL.isEmpty ? nil : serverURL else { return nil }
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        let endpoint = "emby/Items/\(season.id)/Images/Primary"
        var components = URLComponents(string: url + endpoint)
        let maxWidth = DeviceType.current == .iPhone ? 100 : (DeviceType.current == .iPad ? 150 : 200)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: "\(maxWidth)"),
            URLQueryItem(name: "maxHeight", value: "\(Int(Double(maxWidth) * 1.5))"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    var body: some View {
        VStack(spacing: 4) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty, .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: imageWidth, height: imageHeight)
                        .overlay(
                            Image(systemName: "tv")
                                .font(.system(size: DeviceType.current == .iPhone ? 20 : 30))
                                .foregroundColor(.gray)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imageWidth, height: imageHeight)
                        .clipped()
                @unknown default:
                    EmptyView()
                }
            }
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            #if !os(iOS)
            .scaleEffect(isFocused ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            #endif

            Text(season.name ?? "第 \(season.indexNumber ?? 1) 季")
                .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                #if !os(iOS)
                .foregroundColor(isFocused ? .primary : .secondary)
                #else
                .foregroundColor(.secondary)
                #endif
                .lineLimit(1)
        }
        .frame(width: cardWidth)
        #if !os(iOS)
        .focusable()
        .focused($isFocused)
        #endif
    }
}

// MARK: - Episode Card

struct EpisodeCard: View {
    let episode: MediaItem
    let serverURL: String
    let isSelected: Bool

    #if !os(iOS)
    @FocusState private var isFocused: Bool
    #endif

    private var imageHeight: CGFloat {
        DeviceType.current == .iPhone ? 60 : (DeviceType.current == .iPad ? 90 : 110)
    }

    private var imageURL: URL? {
        guard !serverURL.isEmpty else { return nil }
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        let endpoint = "emby/Items/\(episode.id)/Images/Primary"
        var components = URLComponents(string: url + endpoint)
        let maxWidth = DeviceType.current == .iPhone ? 120 : (DeviceType.current == .iPad ? 180 : 200)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: "\(maxWidth)"),
            URLQueryItem(name: "maxHeight", value: "\(Int(Double(maxWidth) * 9.0 / 16.0))"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty, .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(height: imageHeight)
                            .overlay(
                                Image(systemName: "play.circle")
                                    .font(.system(size: DeviceType.current == .iPhone ? 18 : 24))
                                    .foregroundColor(.gray)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: imageHeight)
                            .clipped()
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )

                // Episode number badge
                if let index = episode.indexNumber {
                    Text("第 \(index) 集")
                        .font(DeviceType.current == .iPhone ? .caption2 : .caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .foregroundColor(.white)
                        .padding(3)
                }
            }

            Text(episode.name ?? "第 \(episode.indexNumber ?? 1) 集")
                .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                .lineLimit(2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DeviceType.current == .iPhone ? 4 : 6)
        #if !os(iOS)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isFocused ? Color.blue.opacity(0.1) : Color.clear)
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .focusable()
        .focused($isFocused)
        #endif
    }
}

#Preview {
    NavigationView {
        MediaDetailView(mediaItem: MediaItem(
            id: "1",
            name: "示例电视剧",
            type: "Series",
            overview: "这是一个示例电视剧的描述。这是一个非常精彩的故事，讲述了一个关于冒险和成长的故事。主要角色经历了各种挑战和考验，最终成长为真正的英雄。",
            productionYear: 2024,
            genres: ["动作", "科幻", "冒险"],
            runTimeTicks: 3600000000,
            communityRating: 8.5
        ))
        .environmentObject(ServerManager())
        .environmentObject(AuthManager())
    }
}
