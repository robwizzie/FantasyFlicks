//
//  MoviesViewModel.swift
//  FantasyFlicks
//
//  ViewModel for fetching and managing movie data from TMDB
//

import SwiftUI
import Combine

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
    @Published var selectedGenre: Int? {
        didSet {
            updateFeaturedMovie()
        }
    }

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

    /// Search movies by query. Fetches the first two TMDB pages in parallel,
    /// deduplicates, and reorders so substring matches against the query
    /// (case-insensitive) rank above the rest.
    func searchMovies(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        async let page1 = TMDBService.shared.searchMovies(query: trimmed, page: 1)
        async let page2 = TMDBService.shared.searchMovies(query: trimmed, page: 2)

        do {
            let results1 = try await page1
            // Page 2 may legitimately fail (end of results) — don't let that poison the search.
            let results2 = (try? await page2)?.results ?? []

            var seen = Set<Int>()
            let combined: [TMDBMovie] = (results1.results + results2).filter { seen.insert($0.id).inserted }

            let lowerQuery = trimmed.lowercased()
            let scored = combined.map { movie -> (TMDBMovie, Int) in
                let title = movie.title.lowercased()
                let original = movie.originalTitle?.lowercased() ?? ""
                let voteCount = movie.voteCount ?? 0

                // Score:
                //   -3 exact title match   -> top of list
                //   -2 title starts with   -> near top
                //   -1 contains query      -> above others
                //    0 no title hit        -> use vote count as tiebreaker below
                var score = 0
                if title == lowerQuery || original == lowerQuery {
                    score = -3
                } else if title.hasPrefix(lowerQuery) || original.hasPrefix(lowerQuery) {
                    score = -2
                } else if title.contains(lowerQuery) || original.contains(lowerQuery) {
                    score = -1
                }
                // Use vote count as a secondary signal so well-known films bubble up.
                return (movie, score * 1_000_000 - voteCount)
            }

            let ordered = scored.sorted { $0.1 < $1.1 }.map { $0.0 }

            searchResults = ordered.map { TMDBService.shared.convertToFFMovie($0) }
        } catch {
            searchResults = []
        }
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

    /// Update featured movie based on current filter
    private func updateFeaturedMovie() {
        featuredMovie = filteredMovies().first
    }
}
