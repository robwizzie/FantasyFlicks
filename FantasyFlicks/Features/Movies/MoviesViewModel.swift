//
//  MoviesViewModel.swift
//  FantasyFlicks
//
//  ViewModel for fetching and managing movie data from TMDB
//

import SwiftUI

@MainActor
final class MoviesViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var movies: [FFMovie] = []
    @Published var featuredMovie: FFMovie?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var searchResults: [FFMovie] = []
    @Published var isSearching = false

    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var selectedGenre: Int?

    // MARK: - Pagination

    private var currentPage = 1
    private var totalPages = 1
    var canLoadMore: Bool { currentPage < totalPages && !isLoadingMore }

    // MARK: - Public Methods

    /// Fetch movies for the selected year
    func fetchMovies() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentPage = 1

        do {
            let response = try await TMDBService.shared.discoverMovies(year: selectedYear, page: 1)
            totalPages = response.totalPages

            let ffMovies = response.results.map { tmdbMovie in
                TMDBService.shared.convertToFFMovie(tmdbMovie)
            }

            movies = ffMovies
            featuredMovie = ffMovies.first

        } catch let networkError as NetworkError {
            error = networkError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Load more movies (pagination)
    func loadMoreMovies() async {
        guard canLoadMore, !isLoadingMore else { return }

        isLoadingMore = true
        currentPage += 1

        do {
            let response = try await TMDBService.shared.discoverMovies(year: selectedYear, page: currentPage)

            let newMovies = response.results.map { tmdbMovie in
                TMDBService.shared.convertToFFMovie(tmdbMovie)
            }

            movies.append(contentsOf: newMovies)

        } catch {
            currentPage -= 1 // Revert on failure
        }

        isLoadingMore = false
    }

    /// Search movies by query
    func searchMovies(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        do {
            let response = try await TMDBService.shared.searchMovies(query: query, page: 1)

            searchResults = response.results.map { tmdbMovie in
                TMDBService.shared.convertToFFMovie(tmdbMovie)
            }

        } catch {
            searchResults = []
        }

        isSearching = false
    }

    /// Clear search results
    func clearSearch() {
        searchResults = []
    }

    /// Change year and refetch
    func changeYear(_ year: Int) async {
        selectedYear = year
        await fetchMovies()
    }

    /// Filter by genre (client-side filtering)
    func filteredMovies() -> [FFMovie] {
        guard let genreId = selectedGenre else {
            return movies
        }
        return movies.filter { $0.genreIds.contains(genreId) }
    }
}

// MARK: - Sync wrapper for convertToFFMovie

extension TMDBService {
    /// Synchronous version for use in map operations
    nonisolated func convertToFFMovie(_ tmdbMovie: TMDBMovie) -> FFMovie {
        FFMovie(
            tmdbId: tmdbMovie.id,
            title: tmdbMovie.title,
            originalTitle: tmdbMovie.originalTitle,
            overview: tmdbMovie.overview ?? "",
            posterPath: tmdbMovie.posterPath,
            backdropPath: tmdbMovie.backdropPath,
            releaseDate: tmdbMovie.releaseDate,
            status: .planned,
            runtime: nil,
            genres: [],
            genreIds: tmdbMovie.genreIds ?? [],
            originalLanguage: tmdbMovie.originalLanguage ?? "en",
            productionCompanies: [],
            budget: nil,
            cast: [],
            crew: [],
            popularity: tmdbMovie.popularity ?? 0,
            voteAverage: tmdbMovie.voteAverage ?? 0,
            voteCount: tmdbMovie.voteCount ?? 0
        )
    }
}
