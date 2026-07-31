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
    var participantSeenIds: [String: [Int]]? // userId -> their seen tmdb IDs (for party-wide exclusion)
    var createdAt: Date
    var completedAt: Date?

    var isExpired: Bool {
        guard status != .results else { return false }
        return Date().timeIntervalSince(createdAt) > 86400 // 24 hours
    }

    var participantCount: Int { participantIds.count }

    /// Union of all participants' seen movie IDs
    var allParticipantsSeenIds: Set<Int> {
        guard let participantSeenIds else { return [] }
        return Set(participantSeenIds.values.flatMap { $0 })
    }

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

// MARK: - Exclude Seen Mode

enum ExcludeSeenMode: String, Codable, Sendable, CaseIterable, Hashable {
    case none = "none"
    case mineOnly = "mineOnly"
    case everyoneInParty = "everyoneInParty"

    var displayName: String {
        switch self {
        case .none: return "Include All"
        case .mineOnly: return "Exclude Mine"
        case .everyoneInParty: return "Exclude Everyone's"
        }
    }
}

// MARK: - Audience Mode

/// How well-known the deck should be. Maps to TMDB vote-count bounds — the
/// closest proxy TMDB gives us for "has everyone already heard of this?".
enum AudienceMode: String, Codable, Sendable, CaseIterable, Hashable {
    case balanced
    case crowdPleasers
    case hiddenGems

    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .crowdPleasers: return "Popular"
        case .hiddenGems: return "Deep Cuts"
        }
    }

    var subtitle: String {
        switch self {
        case .balanced: return "A mix of the famous and the overlooked"
        case .crowdPleasers: return "Films most people will recognise"
        case .hiddenGems: return "Well-loved films that flew under the radar"
        }
    }

    var iconName: String {
        switch self {
        case .balanced: return "circle.lefthalf.filled"
        case .crowdPleasers: return "flame.fill"
        case .hiddenGems: return "sparkle.magnifyingglass"
        }
    }

    /// Minimum TMDB vote count. Doubles as a quality floor — a 9.0 with
    /// 12 votes is noise, not a masterpiece.
    var minimumVoteCount: Int {
        switch self {
        case .balanced: return 200
        case .crowdPleasers: return 2_000
        case .hiddenGems: return 150
        }
    }

    /// Upper bound, so "Deep Cuts" doesn't just hand back the same blockbusters.
    var maximumVoteCount: Int? {
        switch self {
        case .balanced, .crowdPleasers: return nil
        case .hiddenGems: return 2_500
        }
    }
}

// MARK: - Content Rating

/// US content rating ceiling. TMDB filters on `certification.lte` with
/// `certification_country=US`.
enum ContentRating: String, Codable, Sendable, CaseIterable, Hashable {
    case g = "G"
    case pg = "PG"
    case pg13 = "PG-13"
    case r = "R"

    var displayName: String { rawValue }

    var subtitle: String {
        switch self {
        case .g: return "All ages"
        case .pg: return "G and PG"
        case .pg13: return "Up to PG-13"
        case .r: return "Up to R"
        }
    }
}

// MARK: - Runtime Limit

/// Upper bound on runtime — the single most-requested Movie Night constraint
/// on a school night.
enum RuntimeLimit: Int, Codable, Sendable, CaseIterable, Hashable {
    case ninety = 90
    case twoHours = 120
    case twoAndAHalfHours = 150

    var displayName: String {
        switch self {
        case .ninety: return "Under 1½ hrs"
        case .twoHours: return "Under 2 hrs"
        case .twoAndAHalfHours: return "Under 2½ hrs"
        }
    }
}

// MARK: - Deck Sources

/// Where a slice of the deck comes from.
///
/// Every source is a `/discover/movie` query, which is the whole point: the
/// filters are applied by TMDB on every request. The old build mixed in the
/// `/trending` and `/now_playing` list endpoints, which silently ignore
/// discover's parameters, so a deck could come back full of films that
/// violated the host's filters.
enum MovieNightDeckSource: String, Sendable, CaseIterable {
    /// Popular right now, within the filters.
    case popular
    /// Highest rated, for depth beyond the popular front page.
    case acclaimed
    /// Released in the last 18 months — the "trending" source.
    case recent
    /// Still in theaters.
    case inTheaters

    var sortBy: String {
        switch self {
        case .popular, .recent, .inTheaters: return "popularity.desc"
        case .acclaimed: return "vote_average.desc"
        }
    }

    /// Extra vote-count floor on top of the audience mode. Sorting by rating
    /// without one surfaces obscure films with a handful of perfect scores.
    var additionalVoteCountFloor: Int? {
        switch self {
        case .acclaimed: return 500
        default: return nil
        }
    }

    /// How far back this source reaches, in days. nil means no window.
    var recencyWindowDays: Int? {
        switch self {
        case .recent: return 550        // ~18 months
        case .inTheaters: return 70     // still on screens
        default: return nil
        }
    }

    /// Restrict to theatrical releases where that's what the source means.
    var theatricalOnly: Bool { self == .inTheaters }
}

// MARK: - Filters

struct MovieNightFilters: Codable, Hashable, Sendable {
    var genreIds: [Int]
    /// Hard "absolutely not tonight" genres. Applied as TMDB `without_genres`,
    /// so a film only needs to touch one of these to be dropped.
    var excludedGenreIds: [Int]
    var watchProviderIds: [Int]
    var watchRegion: String
    /// Widen provider matching past subscription streaming to include rentals
    /// and digital purchases.
    var includeRentals: Bool
    var minVoteAverage: Double
    var audienceMode: AudienceMode
    var includeNowPlaying: Bool
    var includeTrending: Bool
    var deckSize: Int
    var excludeSeenMode: ExcludeSeenMode
    var minimumYear: Int?
    var maximumYear: Int?
    var excludeShorts: Bool
    var maxRuntime: RuntimeLimit?
    var maxCertification: ContentRating?
    /// When false (the default) the deck is limited to English-language films.
    /// Turning it on opens up world cinema — Parasite, Spirited Away, Amélie.
    var includeForeignLanguage: Bool
    /// Drop anything that has already turned up in one of this user's earlier
    /// Movie Night decks, whether or not it was ever watched. Popular films
    /// dominate the discover queries every night otherwise, so the same
    /// shortlist keeps reappearing for a group that swipes regularly.
    var excludePastDeckMovies: Bool
    /// Drop anything sitting on the user's watchlist. Some people want Movie
    /// Night to surface things they haven't already earmarked; others want
    /// exactly the opposite, so this is opt-in.
    var excludeWatchlist: Bool

    static let `default` = MovieNightFilters(
        genreIds: [],
        excludedGenreIds: [],
        watchProviderIds: [],
        watchRegion: "US",
        includeRentals: false,
        minVoteAverage: 6.0,
        audienceMode: .balanced,
        includeNowPlaying: true,
        includeTrending: true,
        deckSize: 25,
        excludeSeenMode: .mineOnly,
        minimumYear: nil,
        maximumYear: nil,
        excludeShorts: true,
        maxRuntime: nil,
        maxCertification: nil,
        includeForeignLanguage: false,
        excludePastDeckMovies: false,
        excludeWatchlist: false
    )

    enum CodingKeys: String, CodingKey {
        case genreIds, watchProviderIds, watchRegion, minVoteAverage
        case includeNowPlaying, includeTrending, deckSize
        case excludeSeenMovies // legacy boolean key
        case excludeSeenMode, minimumYear, excludeShorts
        case includeForeignLanguage
        case excludedGenreIds, includeRentals, audienceMode
        case maximumYear, maxRuntime, maxCertification
        case excludePastDeckMovies, excludeWatchlist
    }

    init(genreIds: [Int], excludedGenreIds: [Int] = [], watchProviderIds: [Int],
         watchRegion: String, includeRentals: Bool = false,
         minVoteAverage: Double, audienceMode: AudienceMode = .balanced,
         includeNowPlaying: Bool, includeTrending: Bool,
         deckSize: Int, excludeSeenMode: ExcludeSeenMode = .mineOnly,
         minimumYear: Int? = nil, maximumYear: Int? = nil,
         excludeShorts: Bool = true, maxRuntime: RuntimeLimit? = nil,
         maxCertification: ContentRating? = nil,
         includeForeignLanguage: Bool = false,
         excludePastDeckMovies: Bool = false,
         excludeWatchlist: Bool = false) {
        self.genreIds = genreIds
        self.excludedGenreIds = excludedGenreIds
        self.watchProviderIds = watchProviderIds
        self.watchRegion = watchRegion
        self.includeRentals = includeRentals
        self.minVoteAverage = minVoteAverage
        self.audienceMode = audienceMode
        self.includeNowPlaying = includeNowPlaying
        self.includeTrending = includeTrending
        self.deckSize = deckSize
        self.excludeSeenMode = excludeSeenMode
        self.minimumYear = minimumYear
        self.maximumYear = maximumYear
        self.excludeShorts = excludeShorts
        self.maxRuntime = maxRuntime
        self.maxCertification = maxCertification
        self.includeForeignLanguage = includeForeignLanguage
        self.excludePastDeckMovies = excludePastDeckMovies
        self.excludeWatchlist = excludeWatchlist
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
        minimumYear = try container.decodeIfPresent(Int.self, forKey: .minimumYear)
        excludeShorts = try container.decodeIfPresent(Bool.self, forKey: .excludeShorts) ?? true
        includeForeignLanguage = try container.decodeIfPresent(Bool.self, forKey: .includeForeignLanguage) ?? false

        // Filters added after the first sessions shipped — all optional so an
        // in-flight session created by an older build still decodes.
        excludedGenreIds = try container.decodeIfPresent([Int].self, forKey: .excludedGenreIds) ?? []
        includeRentals = try container.decodeIfPresent(Bool.self, forKey: .includeRentals) ?? false
        audienceMode = try container.decodeIfPresent(AudienceMode.self, forKey: .audienceMode) ?? .balanced
        maximumYear = try container.decodeIfPresent(Int.self, forKey: .maximumYear)
        maxRuntime = try container.decodeIfPresent(RuntimeLimit.self, forKey: .maxRuntime)
        maxCertification = try container.decodeIfPresent(ContentRating.self, forKey: .maxCertification)
        excludePastDeckMovies = try container.decodeIfPresent(Bool.self, forKey: .excludePastDeckMovies) ?? false
        excludeWatchlist = try container.decodeIfPresent(Bool.self, forKey: .excludeWatchlist) ?? false

        // Backward compatibility: read new enum or fall back to old boolean
        if let mode = try? container.decode(ExcludeSeenMode.self, forKey: .excludeSeenMode) {
            excludeSeenMode = mode
        } else {
            let oldBool = try container.decodeIfPresent(Bool.self, forKey: .excludeSeenMovies) ?? true
            excludeSeenMode = oldBool ? .mineOnly : .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(genreIds, forKey: .genreIds)
        try container.encode(watchProviderIds, forKey: .watchProviderIds)
        try container.encode(watchRegion, forKey: .watchRegion)
        try container.encode(minVoteAverage, forKey: .minVoteAverage)
        try container.encode(includeNowPlaying, forKey: .includeNowPlaying)
        try container.encode(includeTrending, forKey: .includeTrending)
        try container.encode(deckSize, forKey: .deckSize)
        try container.encode(excludeSeenMode, forKey: .excludeSeenMode)
        try container.encodeIfPresent(minimumYear, forKey: .minimumYear)
        try container.encode(excludeShorts, forKey: .excludeShorts)
        try container.encode(includeForeignLanguage, forKey: .includeForeignLanguage)
        try container.encode(excludedGenreIds, forKey: .excludedGenreIds)
        try container.encode(includeRentals, forKey: .includeRentals)
        try container.encode(audienceMode, forKey: .audienceMode)
        try container.encodeIfPresent(maximumYear, forKey: .maximumYear)
        try container.encodeIfPresent(maxRuntime, forKey: .maxRuntime)
        try container.encodeIfPresent(maxCertification, forKey: .maxCertification)
        try container.encode(excludePastDeckMovies, forKey: .excludePastDeckMovies)
        try container.encode(excludeWatchlist, forKey: .excludeWatchlist)
    }

    // MARK: - Summary Helpers

    /// Join names for a single summary chip, keeping it short enough to sit on
    /// one line next to the others. Naming all fourteen genres made one chip
    /// wider than the card, and "Action, Comedy, Adventure, Animation, Crime,
    /// Family, Fanta…" tells the host less than a count does.
    private static func chipList(_ names: [String], showing limit: Int = 3) -> String {
        guard names.count > limit else { return names.joined(separator: ", ") }
        return names.prefix(limit).joined(separator: ", ") + " +\(names.count - limit) more"
    }

    /// Short labels for every non-default filter, for lobby/review chips.
    /// Anything the host set should be visible before they commit to a deck.
    func activeSummaryChips(genreNames: [Int: String] = [:]) -> [(icon: String, text: String)] {
        var chips: [(icon: String, text: String)] = []

        if !genreIds.isEmpty {
            let names = genreIds.compactMap { genreNames[$0] }
            chips.append(("theatermasks.fill", names.isEmpty ? "\(genreIds.count) genres" : Self.chipList(names)))
        }
        if !excludedGenreIds.isEmpty {
            let names = excludedGenreIds.compactMap { genreNames[$0] }
            chips.append(("nosign", "No " + (names.isEmpty ? "\(excludedGenreIds.count) genres" : Self.chipList(names))))
        }
        if !watchProviderIds.isEmpty {
            let names = StreamingProvider.allCases
                .filter { watchProviderIds.contains($0.id) }
                .map { $0.name }
            chips.append(("play.tv.fill", Self.chipList(names)))
            if includeRentals { chips.append(("creditcard.fill", "Rentals OK")) }
        }
        if let maxRuntime {
            chips.append(("timer", maxRuntime.displayName))
        } else if excludeShorts {
            chips.append(("timer", "40 min+"))
        }
        if let maxCertification {
            chips.append(("figure.2.and.child.holdinghands", maxCertification.displayName + " and under"))
        }
        switch (minimumYear, maximumYear) {
        case let (min?, max?): chips.append(("calendar", "\(min)–\(max)"))
        case let (min?, nil): chips.append(("calendar", "\(min)+"))
        case let (nil, max?): chips.append(("calendar", "Up to \(max)"))
        case (nil, nil): break
        }
        if audienceMode != .balanced {
            chips.append((audienceMode.iconName, audienceMode.displayName))
        }
        if minVoteAverage > 0 {
            chips.append(("star.fill", String(format: "%.1f+", minVoteAverage)))
        }
        if includeForeignLanguage {
            chips.append(("globe", "World cinema"))
        }
        if excludeSeenMode != .none {
            chips.append(("eye.slash.fill", excludeSeenMode.displayName))
        }
        if excludePastDeckMovies {
            chips.append(("clock.arrow.circlepath", "No repeats"))
        }
        if excludeWatchlist {
            chips.append(("bookmark.slash.fill", "Not watchlisted"))
        }
        return chips
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

    /// TMDB's own logo for this service.
    ///
    /// Hardcoded rather than fetched: these are stable CDN paths, and reading
    /// them from `/watch/providers/movie` would mean an extra round-trip before
    /// the filter screen could draw anything. Pulled from that endpoint and
    /// each verified to return a 200.
    var logoPath: String {
        switch self {
        case .netflix: return "/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg"
        case .amazonPrime: return "/pvske1MyAoymrs5bguRfVqYiM9a.jpg"
        case .disneyPlus: return "/97yvRBw1GzX7fXprcF80er19ot.jpg"
        case .hulu: return "/bxBlRPEPpMVDc4jMhSrTf2339DW.jpg"
        case .max: return "/jbe4gVSfRlbPTdESXhEKpornsfu.jpg"
        case .appleTVPlus: return "/mcbz1LgtErU9p4UdbZ0rG6RTWHX.jpg"
        case .peacock: return "/2aGrp1xw3qhwCYvNGAJZPdjfeeX.jpg"
        case .paramountPlus: return "/h5DcR0J2EESLitnhR8xLG1QymTE.jpg"
        case .tubi: return "/zLYr7OPvpskMA4S79E3vlCi71iC.jpg"
        case .crunchyroll: return "/fzN5Jok5Ig1eJ7gyNGoMhnLSCfh.jpg"
        }
    }

    var logoURL: URL? {
        URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.ProfileSize.medium.rawValue)\(logoPath)")
    }

    /// Fallback only, for when the logo hasn't loaded yet or can't be reached.
    /// These are approximations — `peacock` was previously used here and isn't
    /// an SF Symbol at all, which is why that one rendered as nothing.
    var iconName: String {
        switch self {
        case .netflix: return "play.rectangle.fill"
        case .amazonPrime: return "shippingbox.fill"
        case .disneyPlus: return "sparkles"
        case .hulu: return "play.square.fill"
        case .max: return "play.circle.fill"
        case .appleTVPlus: return "appletv.fill"
        case .peacock: return "bird.fill"
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
        participantSeenIds: nil,
        createdAt: Date(),
        completedAt: nil
    )
}
