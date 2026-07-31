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

    /// Run one Movie Night deck query. Every source goes through here, so every
    /// filter is applied by TMDB on every request.
    func discoverForMovieNight(
        filters: MovieNightFilters,
        source: MovieNightDeckSource = .popular,
        page: Int = 1
    ) async throws -> TMDBMovieListResponse {
        guard let url = TMDBEndpoint.discoverMovieNight(
            filters: filters,
            source: source,
            page: page
        ).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// How many movies match a filter set, before a deck is built.
    ///
    /// Used by the setup flow to tell the host whether their filters are
    /// workable *before* they invite anyone — the difference between "1,240
    /// movies match" and "3 movies match" is the difference between a good
    /// Movie Night and a dead one.
    func matchCount(for filters: MovieNightFilters) async -> Int? {
        guard let url = TMDBEndpoint.discoverMovieNight(
            filters: filters,
            source: .popular,
            page: 1
        ).url() else { return nil }

        let response: TMDBMovieListResponse? = try? await networkManager.get(url: url)
        return response?.totalResults
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
    /// Every slice of the deck comes from `/discover/movie`, so TMDB enforces
    /// the host's filters on each request. Nothing is stitched in from the
    /// `/trending` or `/now_playing` list endpoints, which ignore discover's
    /// parameters and used to leak films straight past the filters.
    ///
    /// - Parameter excludeTmdbIds: movies to keep out of the deck. This is the
    ///   *complete* exclusion set — the caller decides what it means based on
    ///   the session's `excludeSeenMode`, so passing an empty set genuinely
    ///   gives a deck that can include films the user has already watched.
    func buildMovieNightDeck(filters: MovieNightFilters, excludeTmdbIds: Set<Int> = []) async throws -> [FFMovie] {
        var pool: [TMDBMovie] = []
        var excludedIds = excludeTmdbIds
        let targetSize = filters.deckSize

        /// Keep only movies we haven't already got, and remember them.
        func absorb(_ movies: [TMDBMovie]) {
            for movie in movies where !excludedIds.contains(movie.id) {
                excludedIds.insert(movie.id)
                pool.append(movie)
            }
        }

        // "Don't show me things still in theaters" needs a precise exclusion
        // list, because an in-theater film is a perfectly valid discover result.
        // The now-playing list is only a handful of pages, so read it fully.
        if !filters.includeNowPlaying {
            for page in 1...5 {
                let response = await safeFetch { try await self.getNowPlayingMovies(page: page) }
                for movie in response.results { excludedIds.insert(movie.id) }
                if response.totalPages <= page { break }
            }
        }

        // 1. Popular within the filters — the primary source. Let this one
        //    throw so a real failure surfaces instead of "no movies found".
        let firstPage = try await discoverForMovieNight(filters: filters, source: .popular, page: 1)
        absorb(firstPage.results)

        for page in 2...4 {
            if pool.count >= targetSize * 2 { break }
            if firstPage.totalPages < page { break }
            let response = await safeFetch {
                try await self.discoverForMovieNight(filters: filters, source: .popular, page: page)
            }
            absorb(response.results)
        }

        // 2. Highest rated within the same filters, for depth past the front page.
        for page in 1...3 {
            if pool.count >= targetSize * 3 { break }
            let response = await safeFetch {
                try await self.discoverForMovieNight(filters: filters, source: .acclaimed, page: page)
            }
            absorb(response.results)
            if response.totalPages <= page { break }
        }

        // 3. Optional sources. Both are discover queries with a date window, so
        //    they inherit every filter the host set.
        if filters.includeTrending {
            for page in 1...2 {
                if pool.count >= targetSize * 3 { break }
                let response = await safeFetch {
                    try await self.discoverForMovieNight(filters: filters, source: .recent, page: page)
                }
                absorb(response.results)
                if response.totalPages <= page { break }
            }
        }

        if filters.includeNowPlaying {
            for page in 1...2 {
                if pool.count >= targetSize * 3 { break }
                let response = await safeFetch {
                    try await self.discoverForMovieNight(filters: filters, source: .inTheaters, page: page)
                }
                absorb(response.results)
                if response.totalPages <= page { break }
            }
        }

        // Shuffle for variety, then trim to deck size.
        pool.shuffle()
        return pool.prefix(targetSize).map { convertToFFMovie($0) }
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

// MARK: - Lenient Date Decoding
//
// TMDB sends `"release_date": ""` — an empty string, not null — for films with
// no announced date. `decodeIfPresent` only short-circuits on null, so the
// empty string reaches the decoder's date strategy, throws, and takes the
// *entire* response down with it: one undated film anywhere in a search results
// page was enough to return zero results to the user.
//
// These initialisers read date fields as strings and parse them leniently.
// They live in extensions so each type keeps its memberwise initialiser.

private enum TMDBDateParsing {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// nil for absent, empty, or unparseable values — all of which mean "no date".
    static func date(from raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return dayFormatter.date(from: raw)
    }
}

private extension KeyedDecodingContainer {
    func decodeTMDBDate(forKey key: Key) -> Date? {
        let raw = try? decodeIfPresent(String.self, forKey: key)
        return TMDBDateParsing.date(from: raw ?? nil)
    }
}

extension TMDBMovie {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(Int.self, forKey: .id),
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "",
            originalTitle: try container.decodeIfPresent(String.self, forKey: .originalTitle),
            overview: try container.decodeIfPresent(String.self, forKey: .overview),
            posterPath: try container.decodeIfPresent(String.self, forKey: .posterPath),
            backdropPath: try container.decodeIfPresent(String.self, forKey: .backdropPath),
            releaseDate: container.decodeTMDBDate(forKey: .releaseDate),
            genreIds: try container.decodeIfPresent([Int].self, forKey: .genreIds),
            originalLanguage: try container.decodeIfPresent(String.self, forKey: .originalLanguage),
            popularity: try container.decodeIfPresent(Double.self, forKey: .popularity),
            voteAverage: try container.decodeIfPresent(Double.self, forKey: .voteAverage),
            voteCount: try container.decodeIfPresent(Int.self, forKey: .voteCount),
            adult: try container.decodeIfPresent(Bool.self, forKey: .adult),
            video: try container.decodeIfPresent(Bool.self, forKey: .video)
        )
    }
}

extension TMDBMovieDetails {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(Int.self, forKey: .id),
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "",
            originalTitle: try container.decodeIfPresent(String.self, forKey: .originalTitle),
            tagline: try container.decodeIfPresent(String.self, forKey: .tagline),
            overview: try container.decodeIfPresent(String.self, forKey: .overview),
            posterPath: try container.decodeIfPresent(String.self, forKey: .posterPath),
            backdropPath: try container.decodeIfPresent(String.self, forKey: .backdropPath),
            releaseDate: container.decodeTMDBDate(forKey: .releaseDate),
            status: try container.decodeIfPresent(String.self, forKey: .status),
            runtime: try container.decodeIfPresent(Int.self, forKey: .runtime),
            budget: try container.decodeIfPresent(Int.self, forKey: .budget),
            revenue: try container.decodeIfPresent(Int.self, forKey: .revenue),
            genres: try container.decodeIfPresent([TMDBGenre].self, forKey: .genres) ?? [],
            productionCompanies: try container.decodeIfPresent([TMDBProductionCompany].self, forKey: .productionCompanies) ?? [],
            originalLanguage: try container.decodeIfPresent(String.self, forKey: .originalLanguage),
            popularity: try container.decodeIfPresent(Double.self, forKey: .popularity),
            voteAverage: try container.decodeIfPresent(Double.self, forKey: .voteAverage),
            voteCount: try container.decodeIfPresent(Int.self, forKey: .voteCount),
            homepage: try container.decodeIfPresent(String.self, forKey: .homepage),
            imdbId: try container.decodeIfPresent(String.self, forKey: .imdbId)
        )
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

    // Declared here (not in the extension below) so the memberwise initialiser
    // survives — `getFullMovie` builds a TMDBMovie by hand.
    enum CodingKeys: String, CodingKey {
        case id, title, originalTitle, overview, posterPath, backdropPath
        case releaseDate, genreIds, originalLanguage, popularity
        case voteAverage, voteCount, adult, video
    }
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

    enum CodingKeys: String, CodingKey {
        case id, title, originalTitle, tagline, overview, posterPath, backdropPath
        case releaseDate, status, runtime, budget, revenue, genres
        case productionCompanies, originalLanguage, popularity
        case voteAverage, voteCount, homepage, imdbId
    }
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
