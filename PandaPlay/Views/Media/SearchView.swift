//
//  SearchView.swift
//  PandaPlay
//
//  Created on 2026-03-03.
//

import SwiftUI
import Combine

struct SearchView: View {
    let serverURL: String
    let userId: String
    let accessToken: String

    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedDestination: HomeNavigationDestination?

    private var columns: [GridItem] {
        if DeviceType.current == .iPhone {
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        }
        if DeviceType.current == .iPad {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        }
        return Array(repeating: GridItem(.flexible(), spacing: 24), count: 5)
    }

    private var horizontalPadding: CGFloat {
        DeviceType.current == .iPhone ? 16 : (DeviceType.current == .iPad ? 32 : 60)
    }

    var body: some View {
        ScrollView {
            if viewModel.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 34))
                        .foregroundColor(.secondary)
                    Text("输入关键词搜索电影、电视剧、剧集")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
            } else if viewModel.isLoading {
                ProgressView("搜索中...")
                    .padding(.top, 60)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .padding(.top, 60)
            } else if viewModel.results.isEmpty {
                Text("没有找到相关内容")
                    .foregroundColor(.secondary)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.results, id: \.id) { item in
                        Button {
                            if item.type == "Episode" {
                                selectedDestination = .player(item)
                            } else {
                                selectedDestination = .detail(item)
                            }
                        } label: {
                            MediaPoster(item: item, serverURL: serverURL)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.keyword, prompt: "搜索电影 / 电视剧 / 剧集")
        .navigationDestination(item: $selectedDestination) { destination in
            switch destination {
            case .detail(let item):
                MediaDetailView(mediaItem: item)
            case .player(let item):
                PlayerView(mediaItem: item)
            }
        }
        .onAppear {
            viewModel.configure(serverURL: serverURL, userId: userId, accessToken: accessToken)
        }
        .onChange(of: viewModel.keyword) { _, newValue in
            viewModel.search(keyword: newValue)
        }
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var keyword: String = ""
    @Published var results: [MediaItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var serverURL: String = ""
    private var userId: String = ""
    private var accessToken: String = ""
    private var searchTask: Task<Void, Never>?

    func configure(serverURL: String, userId: String, accessToken: String) {
        self.serverURL = serverURL
        self.userId = userId
        self.accessToken = accessToken
    }

    func search(keyword: String) {
        searchTask?.cancel()

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isLoading = false
            errorMessage = nil
            return
        }

        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.isLoading = true
                    self.errorMessage = nil
                }

                let client = EmbyClient(serverURL: self.serverURL, accessToken: self.accessToken)
                let searchResults = try await client.searchItems(userId: self.userId, query: trimmed, limit: 60)

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.results = searchResults
                    self.isLoading = false
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.results = []
                    self.isLoading = false
                    self.errorMessage = "搜索失败，请检查网络后重试"
                }
            }
        }
    }
}
