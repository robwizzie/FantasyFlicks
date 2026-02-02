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

    var path: String {
        switch self {
        case .discover, .discoverUpcomingBlockbusters: return "/discover/movie"
        case .upcoming: return "/movie/upcoming"
        case .nowPlaying: return "/movie/now_playing"
        case .movieDetails(let id): return "/movie/\(id)"
        case .movieCredits(let id): return "/movie/\(id)/credits"
        case .movieVideos(let id): return "/movie/\(id)/videos"
        case .movieReleaseDates(let id): return "/movie/\(id)/release_dates"
        case .search: return "/search/movie"
        case .genres: return "/genre/movie/list"
        case .configuration: return "/configuration"
        }
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "language", value: "en-US")
        ]

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
}
