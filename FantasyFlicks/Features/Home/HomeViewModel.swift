//
//  HomeViewModel.swift
//  FantasyFlicks
//
//  ViewModel for the home screen - fetches upcoming movies and manages user data
//

import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var upcomingMovies: [FFMovie] = []
    @Published var nowPlayingMovies: [FFMovie] = []
    @Published var isLoadingUpcoming = false
    @Published var isLoadingNowPlaying = false
    @Published var error: String?

    // User leagues (would come from backend/local storage in full implementation)
    @Published var userLeagues: [FFLeague] = []

    // Stats (would be calculated from real data)
    @Published var totalLeagues = 0
    @Published var totalMoviesDrafted = 0
    @Published var bestRank = 0

    // MARK: - Public Methods

    /// Fetch all home screen data
    func fetchHomeData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchUpcomingMovies() }
            group.addTask { await self.fetchNowPlayingMovies() }
        }
    }

    /// Fetch upcoming movies from TMDB
    func fetchUpcomingMovies() async {
        guard !isLoadingUpcoming else { return }

        isLoadingUpcoming = true
        error = nil

        do {
            let response = try await TMDBService.shared.getUpcomingMovies(page: 1)

            upcomingMovies = response.results.prefix(10).map { tmdbMovie in
                TMDBService.shared.convertToFFMovie(tmdbMovie)
            }

        } catch let networkError as NetworkError {
            error = networkError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingUpcoming = false
    }

    /// Fetch now playing movies from TMDB
    func fetchNowPlayingMovies() async {
        guard !isLoadingNowPlaying else { return }

        isLoadingNowPlaying = true

        do {
            let response = try await TMDBService.shared.getNowPlayingMovies(page: 1)

            nowPlayingMovies = response.results.prefix(10).map { tmdbMovie in
                TMDBService.shared.convertToFFMovie(tmdbMovie)
            }

        } catch {
            // Silently fail for secondary content
        }

        isLoadingNowPlaying = false
    }

    /// Refresh all data
    func refresh() async {
        await fetchHomeData()
    }

    /// Check if any data is loading
    var isLoading: Bool {
        isLoadingUpcoming || isLoadingNowPlaying
    }
}
