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

    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedItem: MediaItem?
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 60) {
                    // Header
                    HStack {
                        Text("PandaPlay")
                            .font(.title2)
                            .bold()

                        Spacer()

                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 80)
                    .padding(.top, 60)

                    // Loading State
                    if viewModel.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(2)
                            Text("加载中...")
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 400)
                    }
                    // Content Rows
                    else {
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
                    }

                    Spacer(minLength: 100)
                }
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
        }
        .task {
            await viewModel.loadContent(
                serverURL: serverManager.currentServer?.url ?? "",
                userId: authManager.userId ?? "",
                accessToken: authManager.accessToken ?? ""
            )
        }
    }
}

struct MediaRow: View {
    let title: String
    let items: [MediaItem]
    var serverURL: String
    var onSelect: ((MediaItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(.horizontal, 80)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 40) {
                    ForEach(items) { item in
                        MediaPoster(item: item, serverURL: serverURL)
                            .onTapGesture {
                                onSelect?(item)
                            }
                    }
                }
                .padding(.horizontal, 60)
            }
            .focusSection()
        }
    }
}

struct MediaPoster: View {
    let item: MediaItem
    let serverURL: String
    @FocusState private var isFocused: Bool

    private var imageURL: URL? {
        // Normalize URL
        var url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasSuffix("/") {
            url += "/"
        }
        let endpoint = "emby/Items/\(item.id)/Images/Primary"
        var components = URLComponents(string: url + endpoint)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: "250"),
            URLQueryItem(name: "maxHeight", value: "375"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    var body: some View {
        VStack(spacing: 12) {
            // Poster Image
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 250, height: 375)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 250, height: 375)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 250, height: 375)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .cornerRadius(12)
            .frame(width: 250, height: 375)
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .shadow(radius: isFocused ? 20 : 0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            // Title
            Text(item.name ?? "")
                .font(.caption)
                .lineLimit(2)
                .frame(width: 250)
                .opacity(isFocused ? 1.0 : 0.7)
        }
        .focusable()
        .focused($isFocused)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
        .environmentObject(ServerManager())
        .environmentObject(ErrorManager.shared)
        .environmentObject(ToastManager.shared)
}
