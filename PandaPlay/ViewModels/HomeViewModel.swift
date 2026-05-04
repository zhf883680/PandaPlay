//
//  HomeViewModel.swift
//  PandaPlay
//
//  Created on 2026-03-02.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var hasError: Bool = false
    @Published var errorMessage: String?
    @Published var resumeItems: [MediaItem] = []
    @Published var nextUpItems: [MediaItem] = []
    @Published var latestItems: [MediaItem] = []
    @Published var movies: [MediaItem] = []
    @Published var tvShows: [MediaItem] = []
    @Published var libraries: [MediaItem] = []

    private var embyClient: EmbyClient?

    var hasContent: Bool {
        !resumeItems.isEmpty || !nextUpItems.isEmpty || !latestItems.isEmpty
            || !movies.isEmpty || !tvShows.isEmpty || !libraries.isEmpty
    }

    func loadContent(serverURL: String, userId: String, accessToken: String) async {
        guard !serverURL.isEmpty, !userId.isEmpty, !accessToken.isEmpty else {
            isLoading = false
            hasError = true
            errorMessage = "请先添加并登录服务器"
            return
        }

        isLoading = true
        hasError = false
        errorMessage = nil

        embyClient = EmbyClient(serverURL: serverURL, accessToken: accessToken)

        async let resume = embyClient?.getResumeItems(userId: userId, limit: 12)
        async let nextUp = embyClient?.getNextUp(userId: userId, limit: 12)
        async let latest = embyClient?.getItems(userId: userId, filters: [
            "IncludeItemTypes": "Movie,Series",
            "SortBy": "DateCreated",
            "SortOrder": "Descending",
            "Limit": "20",
            "Recursive": "true",
            "Fields": "Overview,Genres,CommunityRating,ProductionYear"
        ])
        async let movies = embyClient?.getItems(userId: userId, filters: [
            "IncludeItemTypes": "Movie",
            "Recursive": "true",
            "Limit": "50",
            "Fields": "Overview,Genres,CommunityRating,ProductionYear"
        ])
        async let tvShows = embyClient?.getItems(userId: userId, filters: [
            "IncludeItemTypes": "Series",
            "Recursive": "true",
            "Limit": "50",
            "Fields": "Overview,Genres,CommunityRating,ProductionYear"
        ])
        async let libraries = embyClient?.getUserViews(userId: userId)

        do {
            let results = try await [resume, nextUp, latest, movies, tvShows, libraries] as [[MediaItem]?]

            self.resumeItems = results[0] ?? []
            self.nextUpItems = results[1] ?? []
            self.latestItems = results[2] ?? []
            self.movies = results[3] ?? []
            self.tvShows = results[4] ?? []
            self.libraries = results[5] ?? []

            isLoading = false
            hasError = false
        } catch {
            isLoading = false
            hasError = true
            errorMessage = "无法连接到服务器，请检查网络连接"
        }
    }
}
