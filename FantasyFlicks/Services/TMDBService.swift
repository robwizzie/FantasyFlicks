//
//  TMDBService.swift
//  FantasyFlicks
//
//  Service for interacting with The Movie Database (TMDB) API
//

import Foundation

/// Service for fetching movie data from TMDB
@MainActor
final class TMDBService {

    // MARK: - Singleton

    static let shared = TMDBService()

    // MARK: - Properties

    private let networkManager = NetworkManager.shared

    /// Cache for genre list
    private var genreCache: [Int: String] = [:]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Fetch movies for a specific year (for drafting)
    func discoverMovies(year: Int, page: Int = 1) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.discover(year: year, page: page).url() else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.get(url: url)
    }

    /// Fetch upcoming movies
    func getUpcomingMovies(page: Int = 1) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.upcoming(page: page).url() else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.get(url: url)
    }

    /// Fetch upcoming blockbuster movies (high-profile theatrical releases)
    func getUpcomingBlockbusters(page: Int = 1) async throws -> TMDBMovieListResponse {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let today = Date()
        let minDate = dateFormatter.string(from: today)

        // Look up to 1 year ahead for upcoming blockbusters
        let maxDate = dateFormatter.string(from: Calendar.current.date(byAdding: .year, value: 1, to: today) ?? today)

        guard let url = TMDBEndpoint.discoverUpcomingBlockbusters(minDate: minDate, maxDate: maxDate, page: page).url() else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.get(url: url)
    }

    /// Fetch now playing movies
    func getNowPlayingMovies(page: Int = 1) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.nowPlaying(page: page).url() else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.get(url: url)
    }

    /// Fetch detailed movie information
    func getMovieDetails(id: Int) async throws -> TMDBMovieDetails {
        guard let url = TMDBEndpoint.movieDetails(id: id).url() else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.get(url: url)
    }

    /// Fetch movie credits (cast and crew)
    func getMovieCredits(id: Int) async throws -> TMDBCreditsResponse {
        guard let url = TMDBEndpoint.movieCredits(id: id).url() else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.get(url: url)
    }

    /// Fetch movie videos (trailers, etc.)
    func getMovieVideos(id: Int) async throws -> TMDBVideosResponse {
        guard let url = TMDBEndpoint.movieVideos(id: id).url() else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.get(url: url)
    }

    /// Search for movies
    func searchMovies(query: String, page: Int = 1) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.search(query: query, page: page).url() else {
            throw NetworkError.invalidURL
        }

        return try await networkManager.get(url: url)
    }

    /// Fetch genre list
    func getGenres() async throws -> [Genre] {
        guard let url = TMDBEndpoint.genres.url() else {
            throw NetworkError.invalidURL
        }

        let response: TMDBGenresResponse = try await networkManager.get(url: url)

        // Cache genres for later lookup
        for genre in response.genres {
            genreCache[genre.id] = genre.name
        }

        return response.genres.map { Genre(id: $0.id, name: $0.name) }
    }

    /// Convert TMDB movie to our FFMovie model
    func convertToFFMovie(_ tmdbMovie: TMDBMovie, details: TMDBMovieDetails? = nil, credits: TMDBCreditsResponse? = nil) -> FFMovie {
        FFMovie(
            tmdbId: tmdbMovie.id,
            title: tmdbMovie.title,
            originalTitle: tmdbMovie.originalTitle,
            overview: tmdbMovie.overview ?? "",
            posterPath: tmdbMovie.posterPath,
            backdropPath: tmdbMovie.backdropPath,
            releaseDate: tmdbMovie.releaseDate,
            status: details.map { MovieStatus(rawValue: $0.status ?? "Planned") ?? .planned } ?? .planned,
            runtime: details?.runtime,
            genres: details?.genres.map { Genre(id: $0.id, name: $0.name) } ?? [],
            genreIds: tmdbMovie.genreIds ?? [],
            originalLanguage: tmdbMovie.originalLanguage ?? "en",
            productionCompanies: details?.productionCompanies.map {
                ProductionCompany(id: $0.id, name: $0.name, logoPath: $0.logoPath, originCountry: $0.originCountry)
            } ?? [],
            budget: details?.budget,
            cast: credits?.cast.prefix(10).map {
                CastMember(id: $0.id, name: $0.name, character: $0.character ?? "", profilePath: $0.profilePath, order: $0.order ?? 0)
            } ?? [],
            crew: credits?.crew.filter { $0.job == "Director" || $0.job == "Producer" || $0.job == "Writer" }.map {
                CrewMember(id: $0.id, name: $0.name, job: $0.job ?? "", department: $0.department ?? "", profilePath: $0.profilePath)
            } ?? [],
            popularity: tmdbMovie.popularity ?? 0,
            voteAverage: tmdbMovie.voteAverage ?? 0,
            voteCount: tmdbMovie.voteCount ?? 0
        )
    }

    // MARK: - Movie Night Methods

    /// Fetch trending movies
    func getTrendingMovies(timeWindow: String = "week", page: Int = 1) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.trending(timeWindow: timeWindow, page: page).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// Fetch TMDB's "You might also like" recommendations for a movie.
    /// Uses the collaborative filter endpoint (what people who liked this also liked).
    func getRecommendations(movieId: Int, page: Int = 1) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.movieRecommendations(id: movieId, page: page).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// Fetch TMDB's "similar movies" list (shared genres and keywords).
    /// Complements `getRecommendations`, which is behaviour-based — together
    /// they give the recommendation engine both a content and a collaborative view.
    func getSimilarMovies(movieId: Int, page: Int = 1) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.movieSimilar(id: movieId, page: page).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// Discover movies matching a user's taste profile — their strongest genres
    /// and/or the people whose work they rate highly, above a quality floor.
    func discoverByTaste(
        genreIds: [Int],
        peopleIds: [Int],
        excludedGenreIds: [Int] = [],
        minVote: Double = 6.5,
        minVoteCount: Int = 200,
        minimumYear: Int? = nil,
        page: Int = 1
    ) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.discoverByTaste(
            genreIds: genreIds,
            peopleIds: peopleIds,
            excludedGenreIds: excludedGenreIds,
            minVote: minVote,
            minVoteCount: minVoteCount,
            minimumYear: minimumYear,
            page: page
        ).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// Fetch watch providers for a movie
    func getWatchProviders(movieId: Int) async throws -> TMDBWatchProvidersResponse {
        guard let url = TMDBEndpoint.watchProviders(movieId: movieId).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// Discover movies for Movie Night with streaming provider and genre filters
    func discoverForMovieNight(filters: MovieNightFilters, page: Int = 1) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.discoverForMovieNight(
            providerIds: filters.watchProviderIds,
            region: filters.watchRegion,
            genreIds: filters.genreIds,
            minVote: filters.minVoteAverage,
            page: page,
            minimumYear: filters.minimumYear,
            minimumRuntime: filters.excludeShorts ? 40 : nil,
            englishOnly: !filters.includeForeignLanguage
        ).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// Discover top-rated classic movies (sorted by vote average, high vote count)
    func discoverClassics(filters: MovieNightFilters, page: Int = 1) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.discoverClassics(
            providerIds: filters.watchProviderIds,
            region: filters.watchRegion,
            genreIds: filters.genreIds,
            minVote: filters.minVoteAverage,
            page: page,
            minimumYear: filters.minimumYear,
            minimumRuntime: filters.excludeShorts ? 40 : nil,
            englishOnly: !filters.includeForeignLanguage
        ).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// Safely fetch a page, returning empty results on failure instead of throwing
    private func safeFetch(_ fetch: () async throws -> TMDBMovieListResponse) async -> TMDBMovieListResponse {
        do {
            return try await fetch()
        } catch {
            return TMDBMovieListResponse(page: 1, results: [], totalPages: 0, totalResults: 0)
        }
    }

    /// Build a Movie Night deck from TMDB based on filters.
    ///
    /// - Parameter excludeTmdbIds: movies to keep out of the deck. This is the
    ///   *complete* exclusion set — the caller decides what it means based on
    ///   the session's `excludeSeenMode`, so passing an empty set genuinely
    ///   gives a deck that can include films the user has already watched.
    func buildMovieNightDeck(filters: MovieNightFilters, excludeTmdbIds: Set<Int> = []) async throws -> [FFMovie] {
        var allMovies: [TMDBMovie] = []
        var excludedIds = excludeTmdbIds
        let targetSize = filters.deckSize

        // When a source is switched OFF we fetch it anyway, purely to build an
        // exclusion set — that's the only way to keep in-theater or trending
        // titles out of the discover and classics results too.
        if !filters.includeNowPlaying {
            for page in 1...3 {
                let response = await safeFetch { try await self.getNowPlayingMovies(page: page) }
                for movie in response.results { excludedIds.insert(movie.id) }
                if response.totalPages <= page { break }
            }
        }
        if !filters.includeTrending {
            let trending = await safeFetch { try await self.getTrendingMovies(timeWindow: "week", page: 1) }
            for movie in trending.results { excludedIds.insert(movie.id) }
        }

        // 1. Fetch popular movies — this is the primary source, let it throw on failure
        //    so the user sees the real error instead of "no movies found"
        let firstPage = try await discoverForMovieNight(filters: filters, page: 1)
        let firstFiltered = firstPage.results.filter { !excludedIds.contains($0.id) }
        for movie in firstFiltered { excludedIds.insert(movie.id) }
        allMovies.append(contentsOf: firstFiltered)

        // Fetch more pages if needed (these can fail silently)
        for page in 2...4 {
            if allMovies.count >= targetSize * 2 { break }
            if firstPage.totalPages < page { break }
            let response = await safeFetch { try await self.discoverForMovieNight(filters: filters, page: page) }
            let filtered = response.results.filter { !excludedIds.contains($0.id) }
            for movie in filtered { excludedIds.insert(movie.id) }
            allMovies.append(contentsOf: filtered)
        }

        // 2. Fetch top-rated classics (secondary source, safe)
        for page in 1...3 {
            if allMovies.count >= targetSize * 3 { break }
            let response = await safeFetch { try await self.discoverClassics(filters: filters, page: page) }
            let filtered = response.results.filter { !excludedIds.contains($0.id) }
            for movie in filtered { excludedIds.insert(movie.id) }
            allMovies.append(contentsOf: filtered)
            if response.totalPages <= page { break }
        }

        // 3/4. Top up from trending and now-playing. These come from list
        //      endpoints that ignore discover's query parameters, so every
        //      filter has to be re-applied here by hand — otherwise picking
        //      "Netflix, 2010+, no shorts" still leaks 1970s theatrical titles
        //      into the deck.
        if allMovies.count < targetSize && filters.includeTrending {
            let response = await safeFetch { try await self.getTrendingMovies(timeWindow: "week", page: 1) }
            let filtered = await filterTopUp(response.results, filters: filters, excluding: excludedIds)
            for movie in filtered { excludedIds.insert(movie.id) }
            allMovies.append(contentsOf: filtered)
        }

        if allMovies.count < targetSize && filters.includeNowPlaying {
            let response = await safeFetch { try await self.getNowPlayingMovies(page: 1) }
            let filtered = await filterTopUp(response.results, filters: filters, excluding: excludedIds)
            for movie in filtered { excludedIds.insert(movie.id) }
            allMovies.append(contentsOf: filtered)
        }

        // Deduplicate, shuffle for variety, then trim to deck size
        var dedupe = Set<Int>()
        var uniqueMovies = allMovies.filter { dedupe.insert($0.id).inserted }
        uniqueMovies.shuffle()
        let deckMovies = Array(uniqueMovies.prefix(targetSize))

        // Convert to FFMovie
        return deckMovies.map { convertToFFMovie($0) }
    }

    /// Apply the full filter set to results from a list endpoint (trending,
    /// now playing) that can't express the filters as query parameters.
    private func filterTopUp(
        _ movies: [TMDBMovie],
        filters: MovieNightFilters,
        excluding excludedIds: Set<Int>
    ) async -> [TMDBMovie] {
        let shortlist = movies.filter { movie in
            guard !excludedIds.contains(movie.id) else { return false }
            guard (movie.voteAverage ?? 0) >= filters.minVoteAverage else { return false }
            guard matchesGenreFilter(movie: movie, genreIds: filters.genreIds) else { return false }
            guard matchesLanguageFilter(movie: movie, filters: filters) else { return false }
            guard matchesYearFilter(movie: movie, minimumYear: filters.minimumYear) else { return false }
            return true
        }

        // Runtime and streaming availability aren't in the list payload, so
        // they need a per-movie lookup. Only do that when the user actually
        // asked for one of those filters, and cap the work — this is a top-up
        // path, not the primary source.
        let needsRuntimeCheck = filters.excludeShorts
        let needsProviderCheck = !filters.watchProviderIds.isEmpty
        guard needsRuntimeCheck || needsProviderCheck else { return shortlist }

        let capped = Array(shortlist.prefix(20))
        let providerIds = Set(filters.watchProviderIds)
        let region = filters.watchRegion

        var kept: [TMDBMovie] = []
        await withTaskGroup(of: (TMDBMovie, Bool).self) { group in
            for movie in capped {
                group.addTask { [weak self] in
                    guard let self else { return (movie, false) }

                    if needsRuntimeCheck {
                        guard let details = try? await self.getMovieDetails(id: movie.id),
                              (details.runtime ?? 0) >= 40 else {
                            return (movie, false)
                        }
                    }

                    if needsProviderCheck {
                        guard let response = try? await self.getWatchProviders(movieId: movie.id),
                              let flatrate = response.results[region]?.flatrate,
                              flatrate.contains(where: { providerIds.contains($0.providerId) }) else {
                            return (movie, false)
                        }
                    }

                    return (movie, true)
                }
            }
            for await (movie, passed) in group where passed {
                kept.append(movie)
            }
        }
        return kept
    }

    /// Check if a movie matches the selected genre filter (empty = all genres pass)
    private func matchesGenreFilter(movie: TMDBMovie, genreIds: [Int]) -> Bool {
        guard !genreIds.isEmpty else { return true }
        guard let movieGenres = movie.genreIds else { return false }
        return !Set(genreIds).isDisjoint(with: Set(movieGenres))
    }

    private func matchesLanguageFilter(movie: TMDBMovie, filters: MovieNightFilters) -> Bool {
        guard !filters.includeForeignLanguage else { return true }
        return (movie.originalLanguage ?? "en") == "en"
    }

    private func matchesYearFilter(movie: TMDBMovie, minimumYear: Int?) -> Bool {
        guard let minimumYear else { return true }
        guard let date = movie.releaseDate else { return false }
        return Calendar.current.component(.year, from: date) >= minimumYear
    }

    /// Fetch every poster TMDB has on file for a movie. Used by the favorites
    /// editor so users can pick a different artwork for a pinned film.
    func getMovieImages(id: Int) async throws -> TMDBImagesResponse {
        guard let url = TMDBEndpoint.movieImages(id: id).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// Fetch full movie with details and credits.
    ///
    /// Details are required; credits are best-effort. A credits hiccup used to
    /// take the whole movie down with it, which left holes in the Movie Night
    /// deck — a cast list is nice to have, not a reason to drop the film.
    func getFullMovie(id: Int) async throws -> FFMovie {
        async let detailsTask = getMovieDetails(id: id)
        async let creditsTask = getMovieCredits(id: id)

        let details = try await detailsTask
        let credits = try? await creditsTask

        // Convert TMDBMovieDetails to TMDBMovie for the converter
        let tmdbMovie = TMDBMovie(
            id: details.id,
            title: details.title,
            originalTitle: details.originalTitle,
            overview: details.overview,
            posterPath: details.posterPath,
            backdropPath: details.backdropPath,
            releaseDate: details.releaseDate,
            genreIds: details.genres.map { $0.id },
            originalLanguage: details.originalLanguage,
            popularity: details.popularity,
            voteAverage: details.voteAverage,
            voteCount: details.voteCount,
            adult: false,
            video: false
        )

        return convertToFFMovie(tmdbMovie, details: details, credits: credits)
    }
}

// MARK: - TMDB Response Models

struct TMDBMovieListResponse: Codable, Sendable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int
}

struct TMDBMovie: Codable, Sendable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: Date?
    let genreIds: [Int]?
    let originalLanguage: String?
    let popularity: Double?
    let voteAverage: Double?
    let voteCount: Int?
    let adult: Bool?
    let video: Bool?
}

struct TMDBMovieDetails: Codable, Sendable {
    let id: Int
    let title: String
    let originalTitle: String?
    let tagline: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: Date?
    let status: String?
    let runtime: Int?
    let budget: Int?
    let revenue: Int?
    let genres: [TMDBGenre]
    let productionCompanies: [TMDBProductionCompany]
    let originalLanguage: String?
    let popularity: Double?
    let voteAverage: Double?
    let voteCount: Int?
    let homepage: String?
    let imdbId: String?
}

struct TMDBGenre: Codable, Sendable {
    let id: Int
    let name: String
}

struct TMDBProductionCompany: Codable, Sendable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String?
}

struct TMDBCreditsResponse: Codable, Sendable {
    let id: Int
    let cast: [TMDBCastMember]
    let crew: [TMDBCrewMember]
}

struct TMDBCastMember: Codable, Sendable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?
}

struct TMDBCrewMember: Codable, Sendable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?
}

struct TMDBVideosResponse: Codable, Sendable {
    let id: Int
    let results: [TMDBVideo]
}

struct TMDBVideo: Codable, Sendable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool?

    var isYouTubeTrailer: Bool {
        site.lowercased() == "youtube" && type.lowercased() == "trailer"
    }
}

struct TMDBGenresResponse: Codable, Sendable {
    let genres: [TMDBGenre]
}

// MARK: - Watch Providers Response

struct TMDBWatchProvidersResponse: Codable, Sendable {
    let id: Int
    let results: [String: TMDBWatchProviderRegion]
}

struct TMDBWatchProviderRegion: Codable, Sendable {
    let link: String?
    let flatrate: [TMDBWatchProviderEntry]?
    let rent: [TMDBWatchProviderEntry]?
    let buy: [TMDBWatchProviderEntry]?
}

struct TMDBWatchProviderEntry: Codable, Sendable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int?
}

struct TMDBReleaseDatesResponse: Codable, Sendable {
    let id: Int
    let results: [TMDBReleaseDateResult]
}

struct TMDBReleaseDateResult: Codable, Sendable {
    let iso31661: String
    let releaseDates: [TMDBReleaseDate]

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case releaseDates = "release_dates"
    }
}

struct TMDBReleaseDate: Codable, Sendable {
    let certification: String?
    let releaseDate: Date?
    let type: Int? // 1=Premiere, 2=Theatrical (limited), 3=Theatrical, 4=Digital, 5=Physical, 6=TV

    enum CodingKeys: String, CodingKey {
        case certification
        case releaseDate = "release_date"
        case type
    }
}

// MARK: - Images Response

struct TMDBImagesResponse: Codable, Sendable {
    let id: Int
    let posters: [TMDBImage]
    let backdrops: [TMDBImage]
}

struct TMDBImage: Codable, Sendable, Identifiable {
    let filePath: String
    let width: Int
    let height: Int
    let voteAverage: Double?
    let voteCount: Int?
    let iso639_1: String?

    var id: String { filePath }

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case width, height
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case iso639_1 = "iso_639_1"
    }
}
