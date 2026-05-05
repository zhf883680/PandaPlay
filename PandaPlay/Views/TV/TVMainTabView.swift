//
//  TVMainTabView.swift
//  PandaPlay
//
//  tvOS TabView navigation container.
//

import SwiftUI

#if os(tvOS)
struct TVMainTabView: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab: TVTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }
            .tag(TVTab.home)

            // Libraries Tab
            NavigationStack {
                TVLibrariesView()
            }
            .tabItem {
                Label("媒体库", systemImage: "square.stack")
            }
            .tag(TVTab.libraries)

            // Search Tab
            NavigationStack {
                SearchView(
                    serverURL: serverManager.currentServer?.url ?? "",
                    userId: authManager.userId ?? "",
                    accessToken: authManager.accessToken ?? ""
                )
            }
            .tabItem {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .tag(TVTab.search)

            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape.fill")
            }
            .tag(TVTab.settings)
        }
    }
}

// MARK: - TV Libraries View

struct TVLibrariesView: View {
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager
    @State private var libraries: [MediaItem] = []
    @State private var isLoading = true
    @State private var selectedLibrary: MediaItem?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 40), count: 5)

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .scaleEffect(2)
                    .frame(maxWidth: .infinity, minHeight: 400)
            } else if libraries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("暂无媒体库")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                LazyVGrid(columns: columns, spacing: 40) {
                    ForEach(libraries) { library in
                        NavigationLink(value: library) {
                            LibraryTile(library: library)
                                .frame(width: 250, height: 200)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(80)
            }
        }
        .navigationTitle("媒体库")
        .navigationDestination(item: $selectedLibrary) { library in
            LibraryBrowseView(library: library)
        }
        .task {
            await loadLibraries()
        }
    }

    private func loadLibraries() async {
        guard let serverURL = serverManager.currentServer?.url,
              let accessToken = authManager.accessToken,
              let userId = authManager.userId else {
            isLoading = false
            return
        }
        let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
        libraries = (try? await client.getUserViews(userId: userId)) ?? []
        isLoading = false
    }
}

// MARK: - Tab Enum

private enum TVTab {
    case home
    case libraries
    case search
    case settings
}
#endif
