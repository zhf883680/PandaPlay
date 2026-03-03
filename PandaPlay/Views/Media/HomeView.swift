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
                    // Header
                    HStack {
                        Text("PandaPlay")
                            .font(DeviceType.current == .iPhone ? .title3 : .title2)
                            .bold()

                        Spacer()

                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(DeviceType.current == .iPhone ? .title3 : .title2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, verticalPadding)

                    // Loading State
                    if viewModel.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(DeviceType.current == .iPhone ? 1.2 : 2)
                            Text("加载中...")
                                .foregroundColor(.secondary)
                        }
                        .frame(height: DeviceType.current == .iPhone ? 200 : 400)
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

                    Spacer(minLength: DeviceType.current == .iPhone ? 30 : 100)
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
