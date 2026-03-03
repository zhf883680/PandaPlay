//
//  MoreMediaListView.swift
//  PandaPlay
//
//  Created on 2026-03-03.
//

import SwiftUI
import Combine

struct MoreMediaListView: View {
    let section: HomeMediaSection
    let serverURL: String
    let userId: String
    let accessToken: String

    @StateObject private var viewModel = MoreMediaListViewModel()
    @State private var selectedDestination: MoreMediaNavigationDestination?

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
                ForEach(viewModel.items.indices, id: \.self) { index in
                    let item = viewModel.items[index]
                    Button {
                        if section == .resume {
                            selectedDestination = .player(item)
                        } else {
                            selectedDestination = .detail(item)
                        }
                    } label: {
                        MediaPoster(item: item, serverURL: serverURL)
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
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedDestination) { destination in
            switch destination {
            case .detail(let item):
                MediaDetailView(mediaItem: item)
            case .player(let item):
                PlayerView(mediaItem: item)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(MoreMediaSortOption.allCases, id: \.self) { option in
                        Button {
                            viewModel.updateSort(option)
                        } label: {
                            if viewModel.sortOption == option {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    Label("排序", systemImage: "arrow.up.arrow.down")
                }
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
                        Task {
                            await viewModel.reload(
                                section: section,
                                serverURL: serverURL,
                                userId: userId,
                                accessToken: accessToken
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, horizontalPadding)
            }
        }
        .task {
            await viewModel.reload(
                section: section,
                serverURL: serverURL,
                userId: userId,
                accessToken: accessToken
            )
        }
    }
}

@MainActor
final class MoreMediaListViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var sortOption: MoreMediaSortOption = .dateAdded
    @Published var isLoadingInitial: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    private let pageSize: Int = 30
    private var currentSection: HomeMediaSection?
    private var serverURL: String = ""
    private var userId: String = ""
    private var accessToken: String = ""
    private var currentStartIndex: Int = 0
    private var hasMore: Bool = true

    func reload(section: HomeMediaSection, serverURL: String, userId: String, accessToken: String) async {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            errorMessage = "参数无效，请重新登录后重试"
            return
        }

        self.currentSection = section
        self.serverURL = serverURL
        self.userId = userId
        self.accessToken = accessToken

        isLoadingInitial = true
        errorMessage = nil
        currentStartIndex = 0
        hasMore = true
        items = []

        await loadNextPage()
        isLoadingInitial = false
    }

    func updateSort(_ option: MoreMediaSortOption) {
        guard sortOption != option else { return }
        sortOption = option

        Task {
            guard let section = currentSection else { return }
            await reload(section: section, serverURL: serverURL, userId: userId, accessToken: accessToken)
        }
    }

    func loadMoreIfNeeded(currentItem: MediaItem) {
        guard !isLoadingInitial, !isLoadingMore, hasMore else { return }
        guard let index = items.firstIndex(of: currentItem) else { return }

        let threshold = max(0, items.count - 6)
        if index >= threshold {
            Task {
                await loadNextPage()
            }
        }
    }

    private func loadNextPage() async {
        guard !isLoadingMore, hasMore else { return }
        guard let section = currentSection else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let client = EmbyClient(serverURL: serverURL, accessToken: accessToken)
            let nextItems = try await client.getItems(
                userId: userId,
                filters: buildFilters(section: section, startIndex: currentStartIndex)
            )

            items.append(contentsOf: nextItems)
            currentStartIndex += nextItems.count
            hasMore = nextItems.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = "加载失败，请检查网络后重试"
        }
    }

    private func buildFilters(section: HomeMediaSection, startIndex: Int) -> [String: String] {
        var filters: [String: String] = [
            "Recursive": "true",
            "Limit": String(pageSize),
            "StartIndex": String(startIndex),
            "Fields": "Overview,Genres,CommunityRating,ProductionYear,RunTimeTicks,DateCreated"
        ]

        switch sortOption {
        case .dateAdded:
            filters["SortBy"] = "DateCreated"
            filters["SortOrder"] = "Descending"
        case .mediaTime:
            filters["SortBy"] = "RunTimeTicks"
            filters["SortOrder"] = "Descending"
        }

        switch section {
        case .resume:
            filters["Filters"] = "IsResumable"
        case .movies:
            filters["IncludeItemTypes"] = "Movie"
        case .tvShows:
            filters["IncludeItemTypes"] = "Series"
        }

        return filters
    }
}

enum MoreMediaSortOption: CaseIterable {
    case dateAdded
    case mediaTime

    var title: String {
        switch self {
        case .dateAdded:
            return "按添加日期"
        case .mediaTime:
            return "按媒体时间"
        }
    }
}
enum MoreMediaNavigationDestination: Identifiable, Hashable {
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
