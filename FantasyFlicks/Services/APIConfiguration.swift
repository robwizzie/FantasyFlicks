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
        enum ImageSize: String {
            case posterSmall = "w185"
            case posterMedium = "w342"
            case posterLarge = "w500"
            case posterOriginal = "original"
            case backdropSmall = "w300"
            case backdropMedium = "w780"
            case backdropLarge = "w1280"
            case backdropOriginal = "original"
            case profileSmall = "w45"
            case profileMedium = "w185"
            case profileLarge = "h632"
        }

        // ╔════════════════════════════════════════════════════════════════╗
        // ║                    TMDB API TOKEN SETUP                         ║
        // ╠════════════════════════════════════════════════════════════════╣
        // ║  1. Go to: https://www.themoviedb.org/settings/api             ║
        // ║  2. Sign up or log in                                          ║
        // ║  3. Copy the "API Read Access Token" (starts with "eyJ...")    ║
        // ║  4. Paste it below where it says "PASTE YOUR TOKEN HERE"       ║
        // ╚════════════════════════════════════════════════════════════════╝

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

            // ┌──────────────────────────────────────────────────────────────┐
            // │  ⬇️ PASTE YOUR TOKEN HERE (replace the placeholder below) ⬇️  │
            // └──────────────────────────────────────────────────────────────┘
            let developmentToken = "YOUR_TMDB_ACCESS_TOKEN_HERE"

            return developmentToken
        }

        /// Check if a valid token is configured
        static var hasValidToken: Bool {
            let token = accessToken
            return !token.isEmpty &&
                   token != "YOUR_TMDB_ACCESS_TOKEN_HERE" &&
                   token != "YOUR_TOKEN_HERE" &&
                   token.hasPrefix("eyJ")
        }

        /// Build full image URL
        static func imageURL(path: String?, size: ImageSize) -> URL? {
            guard let path = path else { return nil }
            return URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
        }
    }

    // MARK: - Request Timeout

    /// Default timeout for API requests in seconds
    static let requestTimeout: TimeInterval = 30

    /// Timeout for image downloads
    static let imageTimeout: TimeInterval = 60
}

// MARK: - API Endpoints

/// TMDB API endpoints
enum TMDBEndpoint {
    case discover(year: Int, page: Int)
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
        case .discover: return "/discover/movie"
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
