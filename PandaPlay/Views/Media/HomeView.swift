//
//  HomeView.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var toastManager: ToastManager

    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedItem: MediaItem?
    @State private var showSettings: Bool = false
    @State private var showServerSetup: Bool = false
    @State private var showLogin: Bool = false

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
            .navigationDestination(isPresented: Binding(
                get: { selectedItem != nil },
                set: { if !$0 { selectedItem = nil } }
            )) {
                if let item = selectedItem {
                    MediaDetailView(mediaItem: item)
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ServerSwitcher()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(DeviceType.current == .iPhone ? .title3 : .title2)
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
                onSelect: { item in
                    selectedItem = item
                }
            )
        }

        // Recent Movies
        if !viewModel.recentMovies.isEmpty {
            MediaRow(
                title: "最近添加",
                items: viewModel.recentMovies,
                serverURL: serverManager.currentServer?.url ?? "",
                onSelect: { item in
                    selectedItem = item
                }
            )
        }

        // Movies
        if !viewModel.movies.isEmpty {
            MediaRow(
                title: "电影",
                items: viewModel.movies,
                serverURL: serverManager.currentServer?.url ?? "",
                onSelect: { item in
                    selectedItem = item
                }
            )
        }

        // TV Shows
        if !viewModel.tvShows.isEmpty {
            MediaRow(
                title: "电视剧",
                items: viewModel.tvShows,
                serverURL: serverManager.currentServer?.url ?? "",
                onSelect: { item in
                    selectedItem = item
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
    var onSelect: ((MediaItem) -> Void)?

    private var itemSpacing: CGFloat {
        DeviceType.current == .iPhone ? 12 : (DeviceType.current == .iPad ? 20 : 40)
    }

    private var horizontalPadding: CGFloat {
        DeviceType.current == .iPhone ? 16 : (DeviceType.current == .iPad ? 30 : 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DeviceType.current == .iPhone ? .headline : .title2)
                .bold()
                .padding(.horizontal, horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: itemSpacing) {
                    ForEach(items) { item in
                        MediaPoster(item: item, serverURL: serverURL)
                            .onTapGesture {
                                onSelect?(item)
                            }
                    }
                }
                .padding(.horizontal, horizontalPadding - 8)
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
    #if !os(iOS)
    @FocusState private var isFocused: Bool
    #endif

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
            #if !os(iOS)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(radius: isFocused ? 10 : 0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            #endif

            // Title
            Text(item.name ?? "")
                .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                .lineLimit(2)
                .frame(width: posterWidth)
                #if !os(iOS)
                .opacity(isFocused ? 1.0 : 0.7)
                #endif
        }
        #if !os(iOS)
        .focusable()
        .focused($isFocused)
        #endif
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
        .environmentObject(ServerManager())
        .environmentObject(ErrorManager.shared)
        .environmentObject(ToastManager.shared)
}
