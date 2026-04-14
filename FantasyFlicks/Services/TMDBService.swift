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
            page: page
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
            page: page
        ).url() else {
            throw NetworkError.invalidURL
        }
        return try await networkManager.get(url: url)
    }

    /// Build a Movie Night deck from TMDB based on filters
    func buildMovieNightDeck(filters: MovieNightFilters, excludeTmdbIds: Set<Int> = []) async throws -> [FFMovie] {
        var allMovies: [TMDBMovie] = []
        var seenIds = excludeTmdbIds
        let targetSize = filters.deckSize

        // 1. Fetch popular recent movies (popularity sort)
        let popularPages = max(2, Int(ceil(Double(targetSize) / 20.0)))
        for page in 1...popularPages {
            guard allMovies.count < targetSize else { break }
            let response = try await discoverForMovieNight(filters: filters, page: page)
            let filtered = response.results.filter { !seenIds.contains($0.id) }
            for movie in filtered { seenIds.insert(movie.id) }
            allMovies.append(contentsOf: filtered)
            if response.totalPages <= page { break }
        }

        // 2. Fetch top-rated classics (vote_average sort — includes older films)
        let classicPages = max(2, Int(ceil(Double(targetSize) / 20.0)))
        for page in 1...classicPages {
            guard allMovies.count < targetSize * 2 else { break }
            let response = try await discoverClassics(filters: filters, page: page)
            let filtered = response.results.filter { !seenIds.contains($0.id) }
            for movie in filtered { seenIds.insert(movie.id) }
            allMovies.append(contentsOf: filtered)
            if response.totalPages <= page { break }
        }

        // 3. If trending is enabled, add trending too
        if filters.includeTrending {
            for page in 1...2 {
                let trendingResponse = try await getTrendingMovies(timeWindow: "week", page: page)
                let trendingFiltered = trendingResponse.results.filter { movie in
                    (movie.voteAverage ?? 0) >= filters.minVoteAverage &&
                    !seenIds.contains(movie.id)
                }
                for movie in trendingFiltered { seenIds.insert(movie.id) }
                allMovies.append(contentsOf: trendingFiltered)
            }
        }

        // 4. If now playing is enabled
        if filters.includeNowPlaying {
            let nowPlayingResponse = try await getNowPlayingMovies(page: 1)
            let nowPlayingFiltered = nowPlayingResponse.results.filter { movie in
                (movie.voteAverage ?? 0) >= filters.minVoteAverage &&
                !seenIds.contains(movie.id)
            }
            allMovies.append(contentsOf: nowPlayingFiltered)
        }

        // Deduplicate, shuffle for variety, then trim to deck size
        var dedupe = Set<Int>()
        var uniqueMovies = allMovies.filter { dedupe.insert($0.id).inserted }
        uniqueMovies.shuffle()
        let deckMovies = Array(uniqueMovies.prefix(targetSize))

        // Convert to FFMovie
        return deckMovies.map { convertToFFMovie($0) }
    }

    /// Fetch full movie with details and credits
    func getFullMovie(id: Int) async throws -> FFMovie {
        async let detailsTask = getMovieDetails(id: id)
        async let creditsTask = getMovieCredits(id: id)

        let details = try await detailsTask
        let credits = try await creditsTask

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
