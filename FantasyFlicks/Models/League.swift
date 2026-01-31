//
//  League.swift
//  FantasyFlicks
//
//  League model with comprehensive settings for Fantasy Film drafts
//

import Foundation

/// Represents a Fantasy Flicks league
struct FFLeague: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var imageURL: URL?

    // MARK: - League Settings

    var settings: LeagueSettings

    // MARK: - Membership

    /// User ID of the league commissioner (creator)
    let commissionerId: String

    /// IDs of all members (including commissioner)
    var memberIds: [String]

    /// Maximum number of members allowed
    var maxMembers: Int

    /// Invite code for joining the league
    let inviteCode: String

    /// Whether the league is public (discoverable) or private
    var isPublic: Bool

    // MARK: - Draft Info

    /// Current draft status
    var draftStatus: DraftStatus

    /// Scheduled draft start time (nil if not scheduled)
    var draftScheduledAt: Date?

    /// Draft ID once draft is created
    var draftId: String?

    // MARK: - Season Info

    /// Year of movies being drafted (e.g., 2026)
    var seasonYear: Int

    /// Whether the season has ended and final scores are locked
    var isSeasonComplete: Bool

    // MARK: - Metadata

    let createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    var memberCount: Int { memberIds.count }
    var spotsRemaining: Int { maxMembers - memberCount }
    var isFull: Bool { memberCount >= maxMembers }
    var canJoin: Bool { !isFull && draftStatus == .pending }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        imageURL: URL? = nil,
        settings: LeagueSettings = LeagueSettings(),
        commissionerId: String,
        memberIds: [String]? = nil,
        maxMembers: Int = 8,
        inviteCode: String = FFLeague.generateInviteCode(),
        isPublic: Bool = false,
        draftStatus: DraftStatus = .pending,
        draftScheduledAt: Date? = nil,
        draftId: String? = nil,
        seasonYear: Int = Calendar.current.component(.year, from: Date()),
        isSeasonComplete: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.settings = settings
        self.commissionerId = commissionerId
        self.memberIds = memberIds ?? [commissionerId]
        self.maxMembers = maxMembers
        self.inviteCode = inviteCode
        self.isPublic = isPublic
        self.draftStatus = draftStatus
        self.draftScheduledAt = draftScheduledAt
        self.draftId = draftId
        self.seasonYear = seasonYear
        self.isSeasonComplete = isSeasonComplete
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Helpers

    static func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed ambiguous chars
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - League Settings

/// Configurable settings for a league
struct LeagueSettings: Codable, Hashable {

    /// Type of draft order
    var draftType: DraftType

    /// How draft order is determined
    var draftOrderType: DraftOrderType

    /// Manually set draft order (user IDs in order) - used when draftOrderType is .manual
    var manualDraftOrder: [String]?

    /// How scoring works
    var scoringMode: ScoringMode

    /// Whether higher or lower scores win
    var scoringDirection: ScoringDirection

    /// Number of movies each player drafts
    var moviesPerPlayer: Int

    /// Seconds allowed per pick (0 = no timer)
    var pickTimerSeconds: Int

    /// Whether to allow trading after draft
    var allowTrading: Bool

    /// Minimum days before a trade can be vetoed
    var tradeReviewPeriodDays: Int

    /// Whether to include Oscar predictions as bonus scoring
    var includeOscarPredictions: Bool

    /// Oscar prediction bonus multiplier
    var oscarBonusMultiplier: Double

    /// Filter settings for available movies
    var movieFilters: MovieFilterSettings

    init(
        draftType: DraftType = .serpentine,
        draftOrderType: DraftOrderType = .random,
        manualDraftOrder: [String]? = nil,
        scoringMode: ScoringMode = .boxOfficeWorldwide,
        scoringDirection: ScoringDirection = .highest,
        moviesPerPlayer: Int = 5,
        pickTimerSeconds: Int = 120,
        allowTrading: Bool = false,
        tradeReviewPeriodDays: Int = 1,
        includeOscarPredictions: Bool = false,
        oscarBonusMultiplier: Double = 1.5,
        movieFilters: MovieFilterSettings = MovieFilterSettings()
    ) {
        self.draftType = draftType
        self.draftOrderType = draftOrderType
        self.manualDraftOrder = manualDraftOrder
        self.scoringMode = scoringMode
        self.scoringDirection = scoringDirection
        self.moviesPerPlayer = moviesPerPlayer
        self.pickTimerSeconds = pickTimerSeconds
        self.allowTrading = allowTrading
        self.tradeReviewPeriodDays = tradeReviewPeriodDays
        self.includeOscarPredictions = includeOscarPredictions
        self.oscarBonusMultiplier = oscarBonusMultiplier
        self.movieFilters = movieFilters
    }
}

// MARK: - Movie Filter Settings

struct MovieFilterSettings: Codable, Hashable {
    /// Only include theatrical releases (no streaming-only)
    var theatricalOnly: Bool

    /// Minimum production budget (filters out micro-budget films)
    var minimumBudget: Int?

    /// Exclude specific genres
    var excludedGenreIds: [Int]

    /// Only include movies from specific studios
    var includedStudioIds: [Int]?

    init(
        theatricalOnly: Bool = true,
        minimumBudget: Int? = 1_000_000,
        excludedGenreIds: [Int] = [],
        includedStudioIds: [Int]? = nil
    ) {
        self.theatricalOnly = theatricalOnly
        self.minimumBudget = minimumBudget
        self.excludedGenreIds = excludedGenreIds
        self.includedStudioIds = includedStudioIds
    }
}

// MARK: - Enums

enum DraftType: String, Codable, CaseIterable {
    case fixed = "fixed"           // Same order every round
    case serpentine = "serpentine" // Snake draft (1-8, 8-1, 1-8...)

    var displayName: String {
        switch self {
        case .fixed: return "Fixed Order"
        case .serpentine: return "Serpentine (Snake)"
        }
    }

    var description: String {
        switch self {
        case .fixed: return "Same picking order every round"
        case .serpentine: return "Order reverses each round for fairness"
        }
    }
}

enum DraftOrderType: String, Codable, CaseIterable {
    case random = "random"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .random: return "Randomized"
        case .manual: return "Commissioner Sets Order"
        }
    }
}

enum ScoringMode: String, Codable, CaseIterable {
    case boxOfficeDomestic = "box_office_domestic"
    case boxOfficeWorldwide = "box_office_worldwide"
    case ratingsRT = "ratings_rt"           // Rotten Tomatoes
    case ratingsIMDB = "ratings_imdb"       // IMDb
    case ratingsCombined = "ratings_combined" // Average of RT + Audience

    var displayName: String {
        switch self {
        case .boxOfficeDomestic: return "Domestic Box Office"
        case .boxOfficeWorldwide: return "Worldwide Box Office"
        case .ratingsRT: return "Rotten Tomatoes Score"
        case .ratingsIMDB: return "IMDb Rating"
        case .ratingsCombined: return "Combined Ratings"
        }
    }

    var icon: String {
        switch self {
        case .boxOfficeDomestic, .boxOfficeWorldwide: return "dollarsign.circle.fill"
        case .ratingsRT, .ratingsIMDB, .ratingsCombined: return "star.fill"
        }
    }

    var isBoxOffice: Bool {
        switch self {
        case .boxOfficeDomestic, .boxOfficeWorldwide: return true
        default: return false
        }
    }
}

enum ScoringDirection: String, Codable, CaseIterable {
    case highest = "highest" // Highest score wins
    case lowest = "lowest"   // Lowest score wins (for "sleeper" leagues)

    var displayName: String {
        switch self {
        case .highest: return "Highest Wins"
        case .lowest: return "Lowest Wins"
        }
    }
}

enum DraftStatus: String, Codable {
    case pending = "pending"       // Draft not yet started
    case scheduled = "scheduled"   // Draft time set
    case inProgress = "in_progress" // Draft currently happening
    case paused = "paused"         // Draft paused (async)
    case completed = "completed"   // Draft finished

    var displayName: String {
        switch self {
        case .pending: return "Not Scheduled"
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .paused: return "Paused"
        case .completed: return "Completed"
        }
    }

    var color: String {
        switch self {
        case .pending: return "textSecondary"
        case .scheduled: return "goldPrimary"
        case .inProgress: return "ruby"
        case .paused: return "warning"
        case .completed: return "success"
        }
    }
}

// MARK: - Sample Data

extension FFLeague {
    static let sample = FFLeague(
        id: "league_001",
        name: "Box Office Champions",
        description: "May the highest grossing films win! Drafting 2026's biggest blockbusters.",
        settings: LeagueSettings(
            draftType: .serpentine,
            scoringMode: .boxOfficeWorldwide,
            moviesPerPlayer: 5
        ),
        commissionerId: "user_001",
        memberIds: ["user_001", "user_002", "user_003", "user_004"],
        maxMembers: 8,
        draftStatus: .scheduled,
        draftScheduledAt: Date().addingTimeInterval(86400 * 3),
        seasonYear: 2026
    )

    static let sampleLeagues: [FFLeague] = [
        .sample,
        FFLeague(
            id: "league_002",
            name: "Critics Corner",
            description: "Only the best-reviewed films will prevail.",
            settings: LeagueSettings(scoringMode: .ratingsCombined),
            commissionerId: "user_002",
            memberIds: ["user_002", "user_001"],
            draftStatus: .pending,
            seasonYear: 2026
        ),
        FFLeague(
            id: "league_003",
            name: "Sleeper Hits",
            description: "Find the hidden gems! Lowest budget-to-earnings ratio wins.",
            settings: LeagueSettings(scoringMode: .boxOfficeDomestic, scoringDirection: .lowest),
            commissionerId: "user_003",
            memberIds: ["user_003", "user_004", "user_001"],
            draftStatus: .inProgress,
            seasonYear: 2026
        )
    ]
}
