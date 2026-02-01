//
//  FreeAgency.swift
//  FantasyFlicks
//
//  Models for free agency, waiver claims, roster management, and analytics
//  Tracks movie availability, ADP (Average Draft Position), and roster percentages
//

import Foundation

// MARK: - Waiver Claim

/// A request to add a free agent movie and drop an existing one
struct FFWaiverClaim: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let leagueId: String
    let teamId: String
    let userId: String

    // MARK: - Add Movie

    /// Movie being added
    let addMovieId: String
    let addMovieTitle: String
    let addMoviePosterPath: String?

    // MARK: - Drop Movie

    /// Movie being dropped (required to maintain roster size)
    let dropMovieId: String
    let dropMovieTitle: String

    // MARK: - Status & Priority

    /// Current status of the claim
    var status: WaiverStatus

    /// Priority in the waiver order (lower = higher priority)
    let priority: Int

    /// When the claim was made
    let claimedAt: Date

    /// When the claim was processed
    var processedAt: Date?

    /// Reason for denial (if denied)
    var denialReason: String?

    // MARK: - Computed Properties

    var isPending: Bool { status == .pending }
    var wasSuccessful: Bool { status == .approved }

    var addMoviePosterURL: URL? {
        guard let path = addMoviePosterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(path)")
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        leagueId: String,
        teamId: String,
        userId: String,
        addMovieId: String,
        addMovieTitle: String,
        addMoviePosterPath: String? = nil,
        dropMovieId: String,
        dropMovieTitle: String,
        status: WaiverStatus = .pending,
        priority: Int,
        claimedAt: Date = Date(),
        processedAt: Date? = nil,
        denialReason: String? = nil
    ) {
        self.id = id
        self.leagueId = leagueId
        self.teamId = teamId
        self.userId = userId
        self.addMovieId = addMovieId
        self.addMovieTitle = addMovieTitle
        self.addMoviePosterPath = addMoviePosterPath
        self.dropMovieId = dropMovieId
        self.dropMovieTitle = dropMovieTitle
        self.status = status
        self.priority = priority
        self.claimedAt = claimedAt
        self.processedAt = processedAt
        self.denialReason = denialReason
    }
}

/// Status of a waiver claim
enum WaiverStatus: String, Codable, Sendable {
    case pending = "pending"       // Waiting to be processed
    case approved = "approved"     // Successfully processed
    case denied = "denied"         // Denied (movie taken or showing)
    case cancelled = "cancelled"   // User cancelled the claim
    case expired = "expired"       // Claim window expired

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .cancelled: return "Cancelled"
        case .expired: return "Expired"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .approved: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .cancelled: return "xmark.circle"
        case .expired: return "clock.badge.xmark.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: return "goldPrimary"
        case .approved: return "success"
        case .denied, .cancelled, .expired: return "ruby"
        }
    }
}

// MARK: - Transaction Log

/// Record of all roster transactions (adds, drops, trades)
struct FFTransaction: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let leagueId: String
    let teamId: String
    let userId: String

    /// Type of transaction
    let type: TransactionType

    /// Movies involved
    let addedMovieIds: [String]
    let droppedMovieIds: [String]

    /// For trades: the other team
    let otherTeamId: String?

    /// When the transaction occurred
    let occurredAt: Date

    /// Optional notes
    let notes: String?

    enum TransactionType: String, Codable, Sendable {
        case draft = "draft"           // Initial draft pick
        case waiverAdd = "waiver_add"  // Added from waivers
        case waiverDrop = "waiver_drop" // Dropped
        case tradeIn = "trade_in"      // Received in trade
        case tradeOut = "trade_out"    // Sent in trade

        var displayName: String {
            switch self {
            case .draft: return "Drafted"
            case .waiverAdd: return "Added"
            case .waiverDrop: return "Dropped"
            case .tradeIn: return "Trade (In)"
            case .tradeOut: return "Trade (Out)"
            }
        }

        var icon: String {
            switch self {
            case .draft: return "checkmark.circle.fill"
            case .waiverAdd: return "plus.circle.fill"
            case .waiverDrop: return "minus.circle.fill"
            case .tradeIn: return "arrow.down.circle.fill"
            case .tradeOut: return "arrow.up.circle.fill"
            }
        }
    }
}

// MARK: - Movie Availability

/// Tracks a movie's availability status within a league
struct FFMovieAvailability: Codable, Identifiable, Sendable {
    var id: String { "\(movieId)_\(leagueId)" }

    let movieId: String
    let leagueId: String

    /// Whether the movie is available to be picked up
    var isAvailable: Bool

    /// Team that owns this movie (nil if available)
    var ownedByTeamId: String?

    // MARK: - Theater Status

    /// Whether the movie has started showing in theaters
    var hasStartedShowing: Bool

    /// When the movie started showing
    var theaterStartDate: Date?

    /// When the movie stopped showing (left theaters)
    var theaterEndDate: Date?

    /// Whether the movie is currently in theaters
    var isCurrentlyShowing: Bool {
        guard hasStartedShowing else { return false }
        if let endDate = theaterEndDate {
            return Date() < endDate
        }
        return true
    }

    /// Whether this movie can be dropped (not if it's showing)
    var canBeDropped: Bool {
        !hasStartedShowing
    }

    // MARK: - Analytics

    /// Number of times this movie has been rostered
    var timesRostered: Int

    /// Number of times this movie has been dropped
    var timesDropped: Int

    /// Last updated
    var updatedAt: Date

    // MARK: - Initialization

    init(
        movieId: String,
        leagueId: String,
        isAvailable: Bool = true,
        ownedByTeamId: String? = nil,
        hasStartedShowing: Bool = false,
        theaterStartDate: Date? = nil,
        theaterEndDate: Date? = nil,
        timesRostered: Int = 0,
        timesDropped: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.movieId = movieId
        self.leagueId = leagueId
        self.isAvailable = isAvailable
        self.ownedByTeamId = ownedByTeamId
        self.hasStartedShowing = hasStartedShowing
        self.theaterStartDate = theaterStartDate
        self.theaterEndDate = theaterEndDate
        self.timesRostered = timesRostered
        self.timesDropped = timesDropped
        self.updatedAt = updatedAt
    }
}

// MARK: - Roster Percentage

/// Tracks what percentage of teams own a specific movie
struct FFRosterPercentage: Codable, Identifiable, Sendable {
    var id: String { movieId }

    let movieId: String
    let movieTitle: String

    /// Number of leagues where this movie is rostered
    var rosteredCount: Int

    /// Total number of leagues tracked
    var totalLeagues: Int

    /// Last updated
    var updatedAt: Date

    // MARK: - Computed Properties

    var percentage: Double {
        guard totalLeagues > 0 else { return 0 }
        return Double(rosteredCount) / Double(totalLeagues)
    }

    var percentageString: String {
        "\(Int(percentage * 100))%"
    }

    var tier: RosterTier {
        switch percentage {
        case 0.90...: return .mustOwn
        case 0.70..<0.90: return .highlyOwned
        case 0.50..<0.70: return .owned
        case 0.25..<0.50: return .moderate
        case 0.10..<0.25: return .sleeper
        default: return .deepSleeper
        }
    }
}

/// Roster ownership tier
enum RosterTier: String, Codable, Sendable {
    case mustOwn = "must_own"       // 90%+
    case highlyOwned = "highly_owned" // 70-90%
    case owned = "owned"            // 50-70%
    case moderate = "moderate"      // 25-50%
    case sleeper = "sleeper"        // 10-25%
    case deepSleeper = "deep_sleeper" // <10%

    var displayName: String {
        switch self {
        case .mustOwn: return "Must Own"
        case .highlyOwned: return "Highly Owned"
        case .owned: return "Owned"
        case .moderate: return "Moderate"
        case .sleeper: return "Sleeper"
        case .deepSleeper: return "Deep Sleeper"
        }
    }

    var color: String {
        switch self {
        case .mustOwn: return "ruby"
        case .highlyOwned: return "warning"
        case .owned: return "goldPrimary"
        case .moderate: return "textSecondary"
        case .sleeper: return "success"
        case .deepSleeper: return "textTertiary"
        }
    }
}

// MARK: - Average Draft Position (ADP)

/// Tracks average draft position for a movie across all drafts
struct FFAverageDraftPosition: Codable, Identifiable, Sendable {
    var id: String { movieId }

    let movieId: String
    let movieTitle: String
    let posterPath: String?

    /// Average pick number across all drafts
    var averagePosition: Double

    /// Highest pick (earliest)
    var highestPick: Int

    /// Lowest pick (latest)
    var lowestPick: Int

    /// Number of times drafted
    var timesDrafted: Int

    /// Total drafts where this movie was available
    var totalDrafts: Int

    /// Season year
    let seasonYear: Int

    /// Last updated
    var updatedAt: Date

    // MARK: - Computed Properties

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(path)")
    }

    /// Percentage of drafts where this movie was selected
    var draftRate: Double {
        guard totalDrafts > 0 else { return 0 }
        return Double(timesDrafted) / Double(totalDrafts)
    }

    var draftRateString: String {
        "\(Int(draftRate * 100))%"
    }

    /// Round where movie is typically drafted (assuming 5 picks per round, 8 teams)
    var typicalRound: Int {
        let playersPerRound = 8 // Typical league size
        return Int(ceil(averagePosition / Double(playersPerRound)))
    }

    /// Position range string
    var positionRange: String {
        "\(highestPick)-\(lowestPick)"
    }

    var tier: ADPTier {
        switch averagePosition {
        case 0..<5: return .elitePick
        case 5..<10: return .earlyRound
        case 10..<20: return .midRound
        case 20..<30: return .lateRound
        default: return .deepPick
        }
    }
}

/// ADP tier classification
enum ADPTier: String, Codable, Sendable {
    case elitePick = "elite"      // Top 5
    case earlyRound = "early"     // 5-10
    case midRound = "mid"         // 10-20
    case lateRound = "late"       // 20-30
    case deepPick = "deep"        // 30+

    var displayName: String {
        switch self {
        case .elitePick: return "Elite Pick"
        case .earlyRound: return "Early Round"
        case .midRound: return "Mid Round"
        case .lateRound: return "Late Round"
        case .deepPick: return "Deep Pick"
        }
    }

    var color: String {
        switch self {
        case .elitePick: return "goldPrimary"
        case .earlyRound: return "ruby"
        case .midRound: return "warning"
        case .lateRound: return "success"
        case .deepPick: return "textSecondary"
        }
    }
}

// MARK: - Trending Movies

/// Tracks trending add/drop activity for movies
struct FFTrendingMovie: Codable, Identifiable, Sendable {
    var id: String { movieId }

    let movieId: String
    let movieTitle: String
    let posterPath: String?

    /// Net adds in the last 24 hours
    var netAdds24h: Int

    /// Net adds in the last 7 days
    var netAdds7d: Int

    /// Total adds in period
    var totalAdds: Int

    /// Total drops in period
    var totalDrops: Int

    /// Current roster percentage
    var rosterPercentage: Double

    /// Trend direction
    var trend: TrendDirection

    /// Last updated
    var updatedAt: Date

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(path)")
    }
}

/// Trend direction for a movie
enum TrendDirection: String, Codable, Sendable {
    case hotAdd = "hot_add"       // Significant positive trend
    case rising = "rising"        // Moderate positive trend
    case stable = "stable"        // Little change
    case falling = "falling"      // Moderate negative trend
    case coldDrop = "cold_drop"   // Significant negative trend

    var displayName: String {
        switch self {
        case .hotAdd: return "Hot Add"
        case .rising: return "Rising"
        case .stable: return "Stable"
        case .falling: return "Falling"
        case .coldDrop: return "Being Dropped"
        }
    }

    var icon: String {
        switch self {
        case .hotAdd: return "flame.fill"
        case .rising: return "arrow.up.right"
        case .stable: return "minus"
        case .falling: return "arrow.down.right"
        case .coldDrop: return "snowflake"
        }
    }

    var color: String {
        switch self {
        case .hotAdd: return "ruby"
        case .rising: return "goldPrimary"
        case .stable: return "textSecondary"
        case .falling: return "warning"
        case .coldDrop: return "textTertiary"
        }
    }
}

// MARK: - Sample Data

extension FFWaiverClaim {
    static let sample = FFWaiverClaim(
        leagueId: "league_001",
        teamId: "team_001",
        userId: "user_001",
        addMovieId: "movie_new",
        addMovieTitle: "New Blockbuster",
        dropMovieId: "movie_old",
        dropMovieTitle: "Old Movie",
        priority: 1
    )
}

extension FFAverageDraftPosition {
    static let sampleADPs: [FFAverageDraftPosition] = [
        FFAverageDraftPosition(
            movieId: "movie_001",
            movieTitle: "Avatar 4",
            posterPath: nil,
            averagePosition: 1.5,
            highestPick: 1,
            lowestPick: 3,
            timesDrafted: 150,
            totalDrafts: 150,
            seasonYear: 2026,
            updatedAt: Date()
        ),
        FFAverageDraftPosition(
            movieId: "movie_002",
            movieTitle: "Mission: Impossible 9",
            posterPath: nil,
            averagePosition: 4.2,
            highestPick: 1,
            lowestPick: 8,
            timesDrafted: 148,
            totalDrafts: 150,
            seasonYear: 2026,
            updatedAt: Date()
        ),
        FFAverageDraftPosition(
            movieId: "movie_003",
            movieTitle: "Jurassic World 4",
            posterPath: nil,
            averagePosition: 7.8,
            highestPick: 3,
            lowestPick: 15,
            timesDrafted: 142,
            totalDrafts: 150,
            seasonYear: 2026,
            updatedAt: Date()
        )
    ]
}

extension FFTrendingMovie {
    static let sampleTrending: [FFTrendingMovie] = [
        FFTrendingMovie(
            movieId: "movie_trending_1",
            movieTitle: "Surprise Hit 2026",
            posterPath: nil,
            netAdds24h: 45,
            netAdds7d: 180,
            totalAdds: 200,
            totalDrops: 20,
            rosterPercentage: 0.35,
            trend: .hotAdd,
            updatedAt: Date()
        ),
        FFTrendingMovie(
            movieId: "movie_trending_2",
            movieTitle: "Anticipated Sequel",
            posterPath: nil,
            netAdds24h: 12,
            netAdds7d: 50,
            totalAdds: 80,
            totalDrops: 30,
            rosterPercentage: 0.65,
            trend: .rising,
            updatedAt: Date()
        )
    ]
}
