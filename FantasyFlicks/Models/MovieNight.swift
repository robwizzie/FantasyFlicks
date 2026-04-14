//
//  MovieNight.swift
//  FantasyFlicks
//
//  Data models for the Movie Night swipe-to-match feature
//

import Foundation

// MARK: - Session

/// A Movie Night session where friends swipe through a shared deck of movies
struct MovieNightSession: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let hostId: String
    var participantIds: [String]
    let inviteCode: String
    var status: MovieNightStatus
    var deckTmdbIds: [Int]
    var filters: MovieNightFilters
    var participantNames: [String: String] // userId -> displayName
    var createdAt: Date
    var completedAt: Date?

    var isExpired: Bool {
        guard status != .results else { return false }
        return Date().timeIntervalSince(createdAt) > 86400 // 24 hours
    }

    var participantCount: Int { participantIds.count }

    /// Generate a random 6-character invite code
    static func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // No ambiguous chars
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Status

enum MovieNightStatus: String, Codable, Sendable, CaseIterable {
    case lobby
    case swiping
    case results
    case expired

    var displayName: String {
        switch self {
        case .lobby: return "Waiting"
        case .swiping: return "Swiping"
        case .results: return "Complete"
        case .expired: return "Expired"
        }
    }

    var iconName: String {
        switch self {
        case .lobby: return "person.2.fill"
        case .swiping: return "hand.draw.fill"
        case .results: return "checkmark.circle.fill"
        case .expired: return "clock.badge.xmark"
        }
    }
}

// MARK: - Filters

struct MovieNightFilters: Codable, Hashable, Sendable {
    var genreIds: [Int]
    var watchProviderIds: [Int]
    var watchRegion: String
    var minVoteAverage: Double
    var includeNowPlaying: Bool
    var includeTrending: Bool
    var deckSize: Int
    var excludeSeenMovies: Bool

    static let `default` = MovieNightFilters(
        genreIds: [],
        watchProviderIds: [],
        watchRegion: "US",
        minVoteAverage: 6.0,
        includeNowPlaying: true,
        includeTrending: true,
        deckSize: 25,
        excludeSeenMovies: true
    )

    enum CodingKeys: String, CodingKey {
        case genreIds, watchProviderIds, watchRegion, minVoteAverage
        case includeNowPlaying, includeTrending, deckSize, excludeSeenMovies
    }

    init(genreIds: [Int], watchProviderIds: [Int], watchRegion: String,
         minVoteAverage: Double, includeNowPlaying: Bool, includeTrending: Bool,
         deckSize: Int, excludeSeenMovies: Bool = true) {
        self.genreIds = genreIds
        self.watchProviderIds = watchProviderIds
        self.watchRegion = watchRegion
        self.minVoteAverage = minVoteAverage
        self.includeNowPlaying = includeNowPlaying
        self.includeTrending = includeTrending
        self.deckSize = deckSize
        self.excludeSeenMovies = excludeSeenMovies
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genreIds = try container.decode([Int].self, forKey: .genreIds)
        watchProviderIds = try container.decode([Int].self, forKey: .watchProviderIds)
        watchRegion = try container.decode(String.self, forKey: .watchRegion)
        minVoteAverage = try container.decode(Double.self, forKey: .minVoteAverage)
        includeNowPlaying = try container.decode(Bool.self, forKey: .includeNowPlaying)
        includeTrending = try container.decode(Bool.self, forKey: .includeTrending)
        deckSize = try container.decode(Int.self, forKey: .deckSize)
        excludeSeenMovies = try container.decodeIfPresent(Bool.self, forKey: .excludeSeenMovies) ?? true
    }
}

// MARK: - Result Sort Options

enum MovieNightSortOption: String, CaseIterable, Identifiable {
    case matchScore = "Match Score"
    case rating = "Rating"
    case title = "Title"
    case year = "Year"

    var id: String { rawValue }
}

// MARK: - Swipe

/// A single user's swipe on a single movie within a session
struct MovieNightSwipe: Codable, Identifiable, Hashable, Sendable {
    var id: String // "{userId}_{tmdbId}"
    let sessionId: String
    let userId: String
    let tmdbId: Int
    let wantToWatch: Bool
    let hasSeenIt: Bool
    let swipedAt: Date
}

// MARK: - Result (Computed Client-Side)

/// Aggregated result for a single movie across all participants
struct MovieNightResult: Identifiable {
    let id: Int // tmdbId
    let movie: FFMovie
    let matchScore: Double // 0.0 to 1.0
    let swipedRightBy: [String] // user IDs
    let seenBy: [String] // user IDs
    let isUnanimous: Bool
    var streamingProviders: [WatchProvider]

    var matchPercentage: Int {
        Int(matchScore * 100)
    }
}

// MARK: - Watch Provider

struct WatchProvider: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let logoPath: String?

    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.ProfileSize.medium.rawValue)\(logoPath)")
    }
}

// MARK: - Common US Streaming Providers (TMDB IDs)

enum StreamingProvider: Int, CaseIterable, Identifiable {
    case netflix = 8
    case amazonPrime = 9
    case disneyPlus = 337
    case hulu = 15
    case max = 1899
    case appleTVPlus = 350
    case peacock = 386
    case paramountPlus = 531
    case tubi = 73
    case crunchyroll = 283

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .netflix: return "Netflix"
        case .amazonPrime: return "Prime Video"
        case .disneyPlus: return "Disney+"
        case .hulu: return "Hulu"
        case .max: return "Max"
        case .appleTVPlus: return "Apple TV+"
        case .peacock: return "Peacock"
        case .paramountPlus: return "Paramount+"
        case .tubi: return "Tubi"
        case .crunchyroll: return "Crunchyroll"
        }
    }

    var iconName: String {
        switch self {
        case .netflix: return "play.rectangle.fill"
        case .amazonPrime: return "shippingbox.fill"
        case .disneyPlus: return "sparkles"
        case .hulu: return "play.square.fill"
        case .max: return "play.circle.fill"
        case .appleTVPlus: return "appletv.fill"
        case .peacock: return "peacock"
        case .paramountPlus: return "mountain.2.fill"
        case .tubi: return "tv.fill"
        case .crunchyroll: return "leaf.fill"
        }
    }

    var color: String {
        switch self {
        case .netflix: return "E50914"
        case .amazonPrime: return "00A8E1"
        case .disneyPlus: return "113CCF"
        case .hulu: return "1CE783"
        case .max: return "002BE7"
        case .appleTVPlus: return "000000"
        case .peacock: return "000000"
        case .paramountPlus: return "0064FF"
        case .tubi: return "FA382F"
        case .crunchyroll: return "F47521"
        }
    }
}

// MARK: - Sample Data

extension MovieNightSession {
    static let sample = MovieNightSession(
        id: "session-001",
        hostId: "user-001",
        participantIds: ["user-001", "user-002", "user-003"],
        inviteCode: "ABC123",
        status: .lobby,
        deckTmdbIds: [],
        filters: .default,
        participantNames: [
            "user-001": "Alex",
            "user-002": "Jordan",
            "user-003": "Sam"
        ],
        createdAt: Date(),
        completedAt: nil
    )
}
