//
//  DanmakuMatchView.swift
//  PandaPlay
//
//  Manual danmaku matching dialog.
//

import SwiftUI

struct DanmakuMatchView: View {
    let mediaContext: DanmakuMediaContext
    let danmakuService: DanmakuService
    @Environment(\.dismiss) private var dismiss

    @State private var keyword: String = ""
    @State private var searchResults: [DanmakuSearchResult.DanmakuAnime] = []
    @State private var isSearching: Bool = false
    @State private var selectedEpisode: (animeId: Int, episodeId: Int)?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    TextField("搜索弹幕...", text: $keyword)
                        #if os(tvOS)
                        .textFieldStyle(.plain)
                        #else
                        .textFieldStyle(.roundedBorder)
                        #endif
                        .onSubmit {
                            Task { await search() }
                        }

                    Button("搜索") {
                        Task { await search() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(keyword.isEmpty || isSearching)
                }
                .padding()

                if isSearching {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("输入关键词搜索弹幕")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(searchResults) { anime in
                            Section(header: Text(anime.animeTitle ?? "")) {
                                if let episodes = anime.episodes {
                                    ForEach(episodes) { episode in
                                        Button {
                                            selectedEpisode = (animeId: anime.animeId ?? 0, episodeId: episode.episodeId ?? 0)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(episode.episodeTitle ?? "第\(episode.episodeId ?? 0)集")
                                                        .font(.body)
                                                }
                                                Spacer()
                                                if selectedEpisode?.episodeId == episode.episodeId {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    #if os(tvOS)
                    .listStyle(.plain)
                    #else
                    .listStyle(.insetGrouped)
                    #endif
                }
            }
            .navigationTitle("弹幕识别")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        if let sel = selectedEpisode {
                            Task {
                                await danmakuService.manualMatch(
                                    context: mediaContext,
                                    episodeId: sel.episodeId,
                                    title: searchResults.first(where: { $0.animeId == sel.animeId })?.animeTitle
                                )
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedEpisode == nil)
                }
            }
            .onAppear {
                keyword = mediaContext.searchKeyword
                Task { await search() }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func search() async {
        guard !keyword.isEmpty else { return }
        isSearching = true
        searchResults = await danmakuService.searchCandidates(keyword: keyword)
        isSearching = false
    }
}

#Preview {
    DanmakuMatchView(
        mediaContext: DanmakuMediaContext(
            serverId: "test",
            mediaId: "1",
            title: "进击的巨人",
            originalTitle: nil,
            seriesName: "进击的巨人",
            productionYear: 2013,
            seasonNumber: 1,
            episodeNumber: 1,
            durationMs: 1416000,
            fileName: nil
        ),
        danmakuService: DanmakuService()
    )
}
