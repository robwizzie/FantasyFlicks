//
//  APIConfiguration.swift
//  FantasyFlicks
//
//  API configuration and credentials management
//

import Foundation

/// Central configuration for all API services
enum APIConfiguration {

    // MARK: - TMDB API Configuration

    enum TMDB {
        /// Base URL for TMDB API v3
        static let baseURL = "https://api.themoviedb.org/3"

        /// Base URL for TMDB images
        static let imageBaseURL = "https://image.tmdb.org/t/p"

        /// Image size presets
        enum PosterSize: String {
            case small = "w185"
            case medium = "w342"
            case large = "w500"
            case original = "original"
        }

        enum BackdropSize: String {
            case small = "w300"
            case medium = "w780"
            case large = "w1280"
            case original = "original"
        }

        enum ProfileSize: String {
            case small = "w45"
            case medium = "w185"
            case large = "h632"
            case original = "original"
        }

        /// TMDB API Key
        static let apiKey = "88297f6abebf50ca9a4130bb8a073344"

        /// TMDB API Read Access Token (Bearer token)
        static var accessToken: String {
            // Check environment variable first (for CI/CD or Xcode scheme)
            if let token = ProcessInfo.processInfo.environment["TMDB_ACCESS_TOKEN"],
               !token.isEmpty {
                return token
            }

            // Check Secrets.plist (for production builds)
            if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path),
               let token = dict["TMDBAccessToken"] as? String,
               !token.isEmpty,
               token != "YOUR_TOKEN_HERE" {
                return token
            }

            // Development token
            return "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4ODI5N2Y2YWJlYmY1MGNhOWE0MTMwYmI4YTA3MzM0NCIsIm5iZiI6MTc2OTg5MTEzMi4yNzEwMDAxLCJzdWIiOiI2OTdlNjUzYzQ5OThmNzliNDIwZTcyM2MiLCJzY29wZXMiOlsiYXBpX3JlYWQiXSwidmVyc2lvbiI6MX0.1O3HpZOfrWPfOWjas0c61wDum4VsQxhLE2uN7H05iSw"
        }

        /// Check if a valid token is configured
        static var hasValidToken: Bool {
            let token = accessToken
            return !token.isEmpty &&
                   token != "YOUR_TMDB_ACCESS_TOKEN_HERE" &&
                   token != "YOUR_TOKEN_HERE" &&
                   token.hasPrefix("eyJ")
        }

        /// Build full backdrop image URL
        static func backdropURL(path: String?, size: BackdropSize = .medium) -> URL? {
            guard let path = path else { return nil }
            return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
        }

        /// Build full profile image URL
        static func profileURL(path: String?, size: ProfileSize = .medium) -> URL? {
            guard let path = path else { return nil }
            return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
        }
    }

}

// MARK: - API Endpoints

/// TMDB API endpoints
enum TMDBEndpoint: Sendable {
    case discover(year: Int, page: Int)
    case discoverUpcomingBlockbusters(minDate: String, maxDate: String, page: Int)
    case upcoming(page: Int)
    case nowPlaying(page: Int)
    case movieDetails(id: Int)
    case movieCredits(id: Int)
    case movieVideos(id: Int)
    case movieReleaseDates(id: Int)
    case search(query: String, page: Int)
    case genres
    case configuration
    case trending(timeWindow: String, page: Int)
    case watchProviders(movieId: Int)
    /// Every Movie Night deck query. Takes the whole filter struct rather than
    /// a parameter list so there is exactly one place where a filter turns into
    /// a query item — a new filter can't be silently dropped by one call site.
    case discoverMovieNight(filters: MovieNightFilters, source: MovieNightDeckSource, page: Int)
    case movieRecommendations(id: Int, page: Int)
    case movieSimilar(id: Int, page: Int)
    case movieImages(id: Int)
    /// Personalised discovery for the recommendation engine — narrow by the
    /// genres/people a user rates highly, with a quality floor.
    case discoverByTaste(
        genreIds: [Int],
        peopleIds: [Int],
        excludedGenreIds: [Int],
        minVote: Double,
        minVoteCount: Int,
        minimumYear: Int?,
        page: Int
    )

    var path: String {
        switch self {
        case .discover, .discoverUpcomingBlockbusters, .discoverMovieNight, .discoverByTaste: return "/discover/movie"
        case .upcoming: return "/movie/upcoming"
        case .nowPlaying: return "/movie/now_playing"
        case .movieDetails(let id): return "/movie/\(id)"
        case .movieCredits(let id): return "/movie/\(id)/credits"
        case .movieVideos(let id): return "/movie/\(id)/videos"
        case .movieReleaseDates(let id): return "/movie/\(id)/release_dates"
        case .search: return "/search/movie"
        case .genres: return "/genre/movie/list"
        case .configuration: return "/configuration"
        case .trending(let timeWindow, _): return "/trending/movie/\(timeWindow)"
        case .watchProviders(let movieId): return "/movie/\(movieId)/watch/providers"
        case .movieRecommendations(let id, _): return "/movie/\(id)/recommendations"
        case .movieSimilar(let id, _): return "/movie/\(id)/similar"
        case .movieImages(let id): return "/movie/\(id)/images"
        }
    }

    var queryItems: [URLQueryItem] {
        // `language=en-US` narrows TMDB metadata to English and — crucially for
        // search — restricts title matching. We exclude it on the /search/movie
        // endpoint so partial queries like "dune" match across all regions.
        var items: [URLQueryItem] = []
        if case .search = self {
            // no default language param for search
        } else {
            items.append(URLQueryItem(name: "language", value: "en-US"))
        }

        switch self {
        case .discover(let year, let page):
            items.append(contentsOf: [
                URLQueryItem(name: "primary_release_year", value: "\(year)"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "sort_by", value: "popularity.desc"),
                URLQueryItem(name: "with_release_type", value: "2|3"), // Theatrical releases
                URLQueryItem(name: "with_original_language", value: "en")
            ])
        case .discoverUpcomingBlockbusters(let minDate, let maxDate, let page):
            items.append(contentsOf: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "sort_by", value: "popularity.desc"),
                URLQueryItem(name: "primary_release_date.gte", value: minDate),
                URLQueryItem(name: "primary_release_date.lte", value: maxDate),
                URLQueryItem(name: "with_release_type", value: "2|3"), // Theatrical releases
                URLQueryItem(name: "with_original_language", value: "en"),
                URLQueryItem(name: "vote_count.gte", value: "0") // Include movies with anticipation
            ])
        case .upcoming(let page), .nowPlaying(let page):
            items.append(URLQueryItem(name: "page", value: "\(page)"))
            items.append(URLQueryItem(name: "region", value: "US"))
        case .search(let query, let page):
            items.append(contentsOf: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "include_adult", value: "false")
            ])
        case .trending(_, let page):
            items.append(URLQueryItem(name: "page", value: "\(page)"))
        case .discoverMovieNight(let filters, let source, let page):
            items.append(contentsOf: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "sort_by", value: source.sortBy),
                URLQueryItem(name: "vote_average.gte", value: String(format: "%.1f", filters.minVoteAverage)),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "include_video", value: "false")
            ])

            // Vote count: the audience mode sets the floor, and a source can
            // raise it (sorting by rating with no floor surfaces films with
            // three perfect votes).
            let voteFloor = max(
                filters.audienceMode.minimumVoteCount,
                source.additionalVoteCountFloor ?? 0
            )
            items.append(URLQueryItem(name: "vote_count.gte", value: "\(voteFloor)"))
            if let ceiling = filters.audienceMode.maximumVoteCount, ceiling > voteFloor {
                items.append(URLQueryItem(name: "vote_count.lte", value: "\(ceiling)"))
            }

            if !filters.includeForeignLanguage {
                items.append(URLQueryItem(name: "with_original_language", value: "en"))
            }

            if !filters.watchProviderIds.isEmpty {
                items.append(URLQueryItem(name: "with_watch_providers", value: filters.watchProviderIds.map { "\($0)" }.joined(separator: "|")))
                items.append(URLQueryItem(name: "watch_region", value: filters.watchRegion))
                // "free" and "ads" are still watch-tonight options at no extra
                // cost, so they belong in the subscription bucket.
                let monetization = filters.includeRentals
                    ? "flatrate|free|ads|rent|buy"
                    : "flatrate|free|ads"
                items.append(URLQueryItem(name: "with_watch_monetization_types", value: monetization))
            }

            // `|` is OR — a film matching any chosen genre qualifies.
            if !filters.genreIds.isEmpty {
                items.append(URLQueryItem(name: "with_genres", value: filters.genreIds.map { "\($0)" }.joined(separator: "|")))
            }
            // `,` on without_genres is OR too: touching any of them excludes it.
            if !filters.excludedGenreIds.isEmpty {
                items.append(URLQueryItem(name: "without_genres", value: filters.excludedGenreIds.map { "\($0)" }.joined(separator: ",")))
            }

            // Runtime bounds.
            if filters.excludeShorts {
                items.append(URLQueryItem(name: "with_runtime.gte", value: "40"))
            }
            if let maxRuntime = filters.maxRuntime {
                items.append(URLQueryItem(name: "with_runtime.lte", value: "\(maxRuntime.rawValue)"))
            }

            // Content rating ceiling. TMDB needs the country alongside it.
            if let certification = filters.maxCertification {
                items.append(URLQueryItem(name: "certification_country", value: "US"))
                items.append(URLQueryItem(name: "certification.lte", value: certification.rawValue))
            }

            // Release-date window: intersect the host's era filter with the
            // source's own window so "2020+" still narrows an in-theaters pass
            // instead of being overwritten by it.
            let (earliest, latest) = Self.releaseWindow(for: filters, source: source)
            if let earliest {
                items.append(URLQueryItem(name: "primary_release_date.gte", value: earliest))
            }
            if let latest {
                items.append(URLQueryItem(name: "primary_release_date.lte", value: latest))
            }

            if source.theatricalOnly {
                items.append(URLQueryItem(name: "with_release_type", value: "2|3"))
            }
        case .movieRecommendations(_, let page), .movieSimilar(_, let page):
            items.append(URLQueryItem(name: "page", value: "\(page)"))
        case .discoverByTaste(let genreIds, let peopleIds, let excludedGenreIds, let minVote, let minVoteCount, let minimumYear, let page):
            items.append(contentsOf: [
                URLQueryItem(name: "page", value: "\(page)"),
                // Weighted rating rather than raw popularity — the engine is
                // looking for films this person will love, not the ones
                // everyone is streaming this week.
                URLQueryItem(name: "sort_by", value: "vote_average.desc"),
                URLQueryItem(name: "vote_average.gte", value: String(format: "%.1f", minVote)),
                URLQueryItem(name: "vote_count.gte", value: "\(minVoteCount)"),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "include_video", value: "false")
            ])
            // Comma-joined people = AND. We want any of them, so use `|`.
            if !peopleIds.isEmpty {
                items.append(URLQueryItem(name: "with_people", value: peopleIds.map { "\($0)" }.joined(separator: "|")))
            }
            if !genreIds.isEmpty {
                items.append(URLQueryItem(name: "with_genres", value: genreIds.map { "\($0)" }.joined(separator: "|")))
            }
            if !excludedGenreIds.isEmpty {
                items.append(URLQueryItem(name: "without_genres", value: excludedGenreIds.map { "\($0)" }.joined(separator: ",")))
            }
            if let minimumYear {
                items.append(URLQueryItem(name: "primary_release_date.gte", value: "\(minimumYear)-01-01"))
            }
        case .movieImages:
            // TMDB's /movie/{id}/images returns all available posters in every
            // language. Ask for English + untagged (no lang) so we get the
            // English-text posters users expect plus the artworkless versions.
            items.append(URLQueryItem(name: "include_image_language", value: "en,null"))
        default:
            break
        }

        return items
    }

    func url() -> URL? {
        var components = URLComponents(string: APIConfiguration.TMDB.baseURL + path)
        components?.queryItems = queryItems
        return components?.url
    }

    // MARK: - Release Window

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Intersect the host's era filter with the source's own recency window.
    ///
    /// Both constraints have to hold at once: asking for "1990s only" and
    /// leaving the in-theaters source on should yield nothing from that source,
    /// not quietly drop the era filter and serve this month's releases.
    static func releaseWindow(
        for filters: MovieNightFilters,
        source: MovieNightDeckSource
    ) -> (earliest: String?, latest: String?) {
        var earliest: Date?
        var latest: Date?

        if let minimumYear = filters.minimumYear {
            earliest = apiDateFormatter.date(from: "\(minimumYear)-01-01")
        }
        if let maximumYear = filters.maximumYear {
            latest = apiDateFormatter.date(from: "\(maximumYear)-12-31")
        }

        if let windowDays = source.recencyWindowDays,
           let windowStart = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) {
            // Take the later of the two lower bounds.
            earliest = earliest.map { max($0, windowStart) } ?? windowStart
            // A recency source never reaches into the future.
            let today = Date()
            latest = latest.map { min($0, today) } ?? today
        }

        return (
            earliest.map { apiDateFormatter.string(from: $0) },
            latest.map { apiDateFormatter.string(from: $0) }
        )
    }
}
