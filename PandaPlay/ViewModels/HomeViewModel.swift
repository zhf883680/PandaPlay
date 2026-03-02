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
    @Published var resumeItems: [MediaItem] = []
    @Published var recentMovies: [MediaItem] = []
    @Published var movies: [MediaItem] = []
    @Published var tvShows: [MediaItem] = []

    private var embyClient: EmbyClient?

    func loadContent(serverURL: String, userId: String, accessToken: String) async {
        isLoading = true

        embyClient = EmbyClient(serverURL: serverURL, accessToken: accessToken)

        async let resume = embyClient?.getResumeItems(userId: userId, limit: 20)
        async let recent = embyClient?.getRecentItems(userId: userId, limit: 20)
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

        do {
            let results = try await [resume, recent, movies, tvShows] as [ [MediaItem]? ]

            self.resumeItems = results[0] ?? []
            self.recentMovies = results[1] ?? []
            self.movies = results[2] ?? []
            self.tvShows = results[3] ?? []

            isLoading = false
        } catch {
            isLoading = false
        }
    }
}
