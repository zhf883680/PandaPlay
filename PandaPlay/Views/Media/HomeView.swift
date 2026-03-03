//
//  HomeView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var toastManager: ToastManager

    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedDestination: HomeNavigationDestination?
    @State private var showSettings: Bool = false
    @State private var showServerSetup: Bool = false
    @State private var showLogin: Bool = false
    @State private var showSearch: Bool = false
    @State private var selectedSection: HomeMediaSection?

    private var horizontalPadding: CGFloat {
        DeviceType.current == .iPhone ? 16 : (DeviceType.current == .iPad ? 40 : 80)
    }

    private var verticalPadding: CGFloat {
        DeviceType.current == .iPhone ? 12 : (DeviceType.current == .iPad ? 24 : 60)
    }

    private var sectionSpacing: CGFloat {
        DeviceType.current == .iPhone ? 20 : (DeviceType.current == .iPad ? 32 : 60)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: sectionSpacing) {
                    // Content based on state
                    contentView
                }
                .padding(.top, verticalPadding)
            }
            .navigationDestination(item: $selectedDestination) { destination in
                switch destination {
                case .detail(let item):
                    MediaDetailView(mediaItem: item)
                case .player(let item):
                    PlayerView(mediaItem: item)
                }
            }
            .navigationDestination(item: $selectedSection) { section in
                MoreMediaListView(
                    section: section,
                    serverURL: serverManager.currentServer?.url ?? "",
                    userId: authManager.userId ?? "",
                    accessToken: authManager.accessToken ?? ""
                )
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $showSearch) {
                SearchView(
                    serverURL: serverManager.currentServer?.url ?? "",
                    userId: authManager.userId ?? "",
                    accessToken: authManager.accessToken ?? ""
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ServerSwitcher()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button(action: {
                            showSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(DeviceType.current == .iPhone ? .title3 : .title2)
                        }

                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(DeviceType.current == .iPhone ? .title3 : .title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showServerSetup) {
                if let currentServer = serverManager.currentServer {
                    ServerSetupView(editingServer: currentServer)
                } else {
                    ServerSetupView()
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
        .task {
            await refreshContentIfReady()
        }
        .onAppear {
            Task {
                await refreshContentIfReady()
            }
        }
        .onChange(of: serverManager.currentServer) { _ in
            Task {
                await refreshContentIfReady()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _ in
            Task {
                await refreshContentIfReady()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshContentIfReady()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if !serverManager.hasConfiguredServer {
            serverNotConfiguredView
        } else if authManager.isSwitchingServer {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(DeviceType.current == .iPhone ? 1.2 : 2)
                Text("加载中...")
                    .foregroundColor(.secondary)
            }
            .frame(height: DeviceType.current == .iPhone ? 200 : 400)
        } else if !authManager.isAuthenticated {
            loginRequiredView
        } else if viewModel.isLoading {
            // Loading State
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(DeviceType.current == .iPhone ? 1.2 : 2)
                Text("加载中...")
                    .foregroundColor(.secondary)
            }
            .frame(height: DeviceType.current == .iPhone ? 200 : 400)
        } else if viewModel.hasError {
            // Error State
            errorView
        } else if !viewModel.hasContent {
            // Empty State
            emptyView
        } else {
            // Content Rows
            contentRows
        }
    }

    private var serverNotConfiguredView: some View {
        VStack(spacing: DeviceType.current == .iPhone ? 16 : 24) {
            Image(systemName: "server.rack")
                .font(.system(size: DeviceType.current == .iPhone ? 48 : 64))
                .foregroundColor(.secondary)

            Text("还没有添加服务器")
                .font(DeviceType.current == .iPhone ? .body : .title3)
                .foregroundColor(.primary)

            Text("请先添加 Emby/Jellyfin 服务器，然后就可以在首页浏览媒体列表")
                .font(DeviceType.current == .iPhone ? .caption : .body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("添加服务器") {
                showServerSetup = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: DeviceType.current == .iPhone ? 240 : 420)
    }

    private var loginRequiredView: some View {
        VStack(spacing: DeviceType.current == .iPhone ? 16 : 24) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: DeviceType.current == .iPhone ? 48 : 64))
                .foregroundColor(.orange)

            Text("未登录或登录已失效")
                .font(DeviceType.current == .iPhone ? .body : .title3)
                .foregroundColor(.primary)

            if let server = serverManager.currentServer {
                Text("当前服务器：\(server.name)")
                    .font(DeviceType.current == .iPhone ? .caption : .body)
                    .foregroundColor(.secondary)
            }

            Button("去登录") {
                showLogin = true
            }
            .buttonStyle(.borderedProminent)

            Button("编辑服务器") {
                showServerSetup = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: DeviceType.current == .iPhone ? 240 : 420)
    }

    private var errorView: some View {
        VStack(spacing: DeviceType.current == .iPhone ? 16 : 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: DeviceType.current == .iPhone ? 48 : 64))
                .foregroundColor(.orange)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(DeviceType.current == .iPhone ? .body : .title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("重试") {
                Task {
                    await viewModel.loadContent(
                        serverURL: serverManager.currentServer?.url ?? "",
                        userId: authManager.userId ?? "",
                        accessToken: authManager.accessToken ?? ""
                    )
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: DeviceType.current == .iPhone ? 200 : 400)
    }

    private var emptyView: some View {
        VStack(spacing: DeviceType.current == .iPhone ? 16 : 24) {
            Image(systemName: "film.stack")
                .font(.system(size: DeviceType.current == .iPhone ? 48 : 64))
                .foregroundColor(.gray)

            Text("暂无内容")
                .font(DeviceType.current == .iPhone ? .body : .title3)
                .foregroundColor(.secondary)

            Text("服务器上还没有媒体内容，或者您没有访问权限")
                .font(DeviceType.current == .iPhone ? .caption : .body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .frame(minHeight: DeviceType.current == .iPhone ? 200 : 400)
    }

    private func refreshContentIfReady() async {
        guard authManager.isAuthenticated else {
            return
        }

        await viewModel.loadContent(
            serverURL: serverManager.currentServer?.url ?? "",
            userId: authManager.userId ?? "",
            accessToken: authManager.accessToken ?? ""
        )
    }

    @ViewBuilder
    private var contentRows: some View {
        // Resume Items
        if !viewModel.resumeItems.isEmpty {
            MediaRow(
                title: "继续观看",
                items: viewModel.resumeItems,
                serverURL: serverManager.currentServer?.url ?? "",
                displayMode: .resume,
                onSelect: { item in
                    selectedDestination = .player(item)
                }
            )
        }

        // Movies
        if !viewModel.movies.isEmpty {
            MediaRow(
                title: "电影",
                items: viewModel.movies,
                serverURL: serverManager.currentServer?.url ?? "",
                onMore: {
                    selectedSection = .movies
                },
                onSelect: { item in
                    selectedDestination = .detail(item)
                }
            )
        }

        // TV Shows
        if !viewModel.tvShows.isEmpty {
            MediaRow(
                title: "电视剧",
                items: viewModel.tvShows,
                serverURL: serverManager.currentServer?.url ?? "",
                onMore: {
                    selectedSection = .tvShows
                },
                onSelect: { item in
                    selectedDestination = .detail(item)
                }
            )
        }

        Spacer(minLength: DeviceType.current == .iPhone ? 30 : 100)
    }
}

struct MediaRow: View {
    let title: String
    let items: [MediaItem]
    var serverURL: String
    var displayMode: MediaPosterDisplayMode = .standard
    var onMore: (() -> Void)?
    var onSelect: ((MediaItem) -> Void)?
    private let maxPreviewCount: Int = 10

    private var itemSpacing: CGFloat {
        DeviceType.current == .iPhone ? 12 : (DeviceType.current == .iPad ? 20 : 40)
    }

    private var horizontalPadding: CGFloat {
        DeviceType.current == .iPhone ? 16 : (DeviceType.current == .iPad ? 30 : 60)
    }

    var body: some View {
        let previewItems = Array(items.prefix(maxPreviewCount))

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(DeviceType.current == .iPhone ? .headline : .title2)
                    .bold()

                Spacer(minLength: 8)

                if title != "继续观看", items.count > maxPreviewCount, let onMore {
                    Button("更多") {
                        onMore()
                    }
                    .font(DeviceType.current == .iPhone ? .subheadline : .headline)
                }
            }
            .padding(.horizontal, horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: itemSpacing) {
                    ForEach(previewItems.indices, id: \.self) { index in
                        let item = previewItems[index]
                        Button {
                            onSelect?(item)
                        } label: {
                            MediaPoster(
                                item: item,
                                serverURL: serverURL,
                                displayMode: displayMode
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
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

struct MediaPoster: View {
    let item: MediaItem
    let serverURL: String
    var displayMode: MediaPosterDisplayMode = .standard

    private var posterWidth: CGFloat {
        DeviceType.current == .iPhone ? 120 : (DeviceType.current == .iPad ? 180 : 250)
    }

    private var posterHeight: CGFloat {
        DeviceType.current == .iPhone ? 180 : (DeviceType.current == .iPad ? 270 : 375)
    }

    private var imageURL: URL? {
        // Normalize URL
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        let endpoint = "emby/Items/\(item.id)/Images/Primary"
        var components = URLComponents(string: url + endpoint)
        let maxWidth = DeviceType.current == .iPhone ? 150 : (DeviceType.current == .iPad ? 200 : 250)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: "\(maxWidth)"),
            URLQueryItem(name: "maxHeight", value: "\(Int(Double(maxWidth) * 1.5))"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    var body: some View {
        VStack(spacing: 6) {
            // Poster Image
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: posterWidth, height: posterHeight)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: posterWidth, height: posterHeight)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: posterWidth, height: posterHeight)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: DeviceType.current == .iPhone ? 24 : 40))
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .cornerRadius(8)
            .frame(width: posterWidth, height: posterHeight)

            if displayMode == .resume {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resumePrimaryTitle)
                        .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .truncationMode(.tail)

                    Text(resumeSecondaryTitle)
                        .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .truncationMode(.tail)
                }
                .frame(width: posterWidth, alignment: .leading)
            } else {
                // Title
                Text(item.name ?? "")
                    .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)
                    .frame(width: posterWidth)
            }
        }
        .contentShape(Rectangle())
    }

    private var resumePrimaryTitle: String {
        if let seriesName = item.seriesName, !seriesName.isEmpty {
            return seriesName
        }
        return item.name ?? ""
    }

    private var resumeSecondaryTitle: String {
        let episodeLabel: String? = {
            switch (item.parentIndexNumber, item.indexNumber) {
            case let (.some(season), .some(episode)):
                return "第\(season)季 第\(episode)集"
            case let (_, .some(episode)):
                return "第\(episode)集"
            default:
                return nil
            }
        }()

        let displayName = item.name ?? ""
        if let episodeLabel, !displayName.isEmpty {
            return "\(episodeLabel) · \(displayName)"
        }
        if let episodeLabel {
            return episodeLabel
        }
        return displayName
    }
}

enum MediaPosterDisplayMode {
    case standard
    case resume
}

enum HomeNavigationDestination: Identifiable, Hashable {
    case detail(MediaItem)
    case player(MediaItem)

    var id: String {
        switch self {
        case .detail(let item):
            return "detail-\(item.id)"
        case .player(let item):
            return "player-\(item.id)"
        }
    }
}

enum HomeMediaSection: String, Identifiable, CaseIterable {
    case resume
    case movies
    case tvShows

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resume:
            return "继续观看"
        case .movies:
            return "电影"
        case .tvShows:
            return "电视剧"
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
        .environmentObject(ServerManager())
        .environmentObject(ErrorManager.shared)
        .environmentObject(ToastManager.shared)
}
