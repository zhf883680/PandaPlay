//
//  LibraryBrowseView.swift
//  PandaPlay
//
//  Created on 2026-05-02.
//

import SwiftUI
import Combine

struct LibraryBrowseView: View {
    let library: MediaItem

    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var authManager: AuthManager

    @StateObject private var viewModel = LibraryBrowseViewModel()
    @State private var selectedItem: HomeNavigationDestination?

    private var horizontalPadding: CGFloat {
        DeviceType.current == .iPhone ? 16 : (DeviceType.current == .iPad ? 32 : 60)
    }

    private var columns: [GridItem] {
        if DeviceType.current == .iPhone {
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        }
        if DeviceType.current == .iPad {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        }
        return Array(repeating: GridItem(.flexible(), spacing: 24), count: 5)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                ForEach(viewModel.items) { item in
                    Button {
                        if item.type == "CollectionFolder" || item.type == "Folder" {
                            selectedItem = .library(item)
                        } else if item.type == "Movie" {
                            selectedItem = .player(item)
                        } else {
                            selectedItem = .detail(item)
                        }
                    } label: {
                        if item.type == "CollectionFolder" || item.type == "Folder" {
                            folderCard(item: item)
                        } else {
                            MediaPoster(item: item, serverURL: serverManager.currentServer?.url ?? "")
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .onAppear {
                        viewModel.loadMoreIfNeeded(currentItem: item)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .gridCellColumns(columns.count)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle(library.name ?? "媒体库")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $selectedItem) { destination in
            switch destination {
            case .detail(let item):
                MediaDetailView(mediaItem: item)
            case .player(let item):
                PlayerView(mediaItem: item)
            case .library(let item):
                LibraryBrowseView(library: item)
            }
        }
        .overlay {
            if viewModel.isLoadingInitial {
                ProgressView("加载中...")
            } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task { await viewModel.reload() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, horizontalPadding)
            }
        }
        .task {
            await viewModel.load(
                library: library,
                serverURL: serverManager.currentServer?.url ?? "",
                userId: authManager.userId ?? "",
                accessToken: authManager.accessToken ?? ""
            )
        }
    }

    @ViewBuilder
    private func folderCard(item: MediaItem) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.15))
                    .aspectRatio(2/3, contentMode: .fit)

                Image(systemName: "folder")
                    .font(.system(size: DeviceType.current == .iPhone ? 24 : 36))
                    .foregroundColor(.blue)
            }
            .cornerRadius(8)

            Text(item.name ?? "文件夹")
                .font(DeviceType.current == .iPhone ? .caption2 : .caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

@MainActor
class LibraryBrowseViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var isLoadingInitial: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    private let pageSize: Int = 30
    private var serverURL: String = ""
    private var userId: String = ""
    private var accessToken: String = ""
    private var currentParentId: String = ""
    private var currentStartIndex: Int = 0
    private var hasMore: Bool = true

    func load(library: MediaItem, serverURL: String, userId: String, accessToken: String) async {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            errorMessage = "参数无效，请重新登录后重试"
            return
        }

        self.serverURL = serverURL
        self.userId = userId
        self.accessToken = accessToken
        self.currentParentId = library.id

        isLoadingInitial = true
        errorMessage = nil
        currentStartIndex = 0
        hasMore = true
        items = []

        await loadNextPage()
        isLoadingInitial = false
    }

    func reload() async {
        guard !currentParentId.isEmpty else { return }
        currentStartIndex = 0
        hasMore = true
        items = []
        isLoadingInitial = true
        errorMessage = nil
        await loadNextPage()
        isLoadingInitial = false
    }

    func loadMoreIfNeeded(currentItem: MediaItem) {
        guard !isLoadingInitial, !isLoadingMore, hasMore else { return }
        guard let index = items.firstIndex(of: currentItem) else { return }

        let threshold = max(0, items.count - 6)
        if index >= threshold {
            Task { await loadNextPage() }
        }
    }

    private func loadNextPage() async {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
            let nextItems = try await client.getItems(userId: userId, filters: [
                "ParentId": currentParentId,
                "Recursive": "false",
                "Limit": String(pageSize),
                "StartIndex": String(currentStartIndex),
                "Fields": "Overview,Genres,CommunityRating,ProductionYear,RunTimeTicks,DateCreated",
                "SortBy": "SortName",
                "SortOrder": "Ascending"
            ])

            items.append(contentsOf: nextItems)
            currentStartIndex += nextItems.count
            hasMore = nextItems.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = "加载失败，请检查网络后重试"
        }
    }
}
