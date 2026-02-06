//
//  League.swift
//  FantasyFlicks
//
//  League model with comprehensive settings for Fantasy Film drafts
//  Supports Box Office, Rotten Tomatoes, and Oscar prediction modes
//

import Foundation

// MARK: - League Mode

/// The primary game mode for a league
enum LeagueMode: String, Codable, CaseIterable, Sendable {
    case boxOffice = "box_office"           // Score by box office earnings (DEFAULT)
    case rottenTomatoes = "rotten_tomatoes" // Score by RT + Audience scores
    case oscar = "oscar"                    // Pick Oscar winners

    var displayName: String {
        switch self {
        case .boxOffice: return "Box Office"
        case .rottenTomatoes: return "Rotten Tomatoes"
        case .oscar: return "Oscar Predictions"
        }
    }

    var description: String {
        switch self {
        case .boxOffice: return "Draft movies and score points based on box office earnings"
        case .rottenTomatoes: return "Draft movies and score based on critic and audience ratings"
        case .oscar: return "Pick Oscar winners from any category to earn points"
        }
    }

    var icon: String {
        switch self {
        case .boxOffice: return "dollarsign.circle.fill"
        case .rottenTomatoes: return "star.circle.fill"
        case .oscar: return "trophy.fill"
        }
    }

    var accentColorName: String {
        switch self {
        case .boxOffice: return "goldPrimary"
        case .rottenTomatoes: return "ruby"
        case .oscar: return "goldPrimary"
        }
    }
}

// MARK: - Box Office Cutoff

/// When box office scoring ends for a movie
enum BoxOfficeCutoff: String, Codable, CaseIterable, Sendable {
    case yearEnd = "year_end"               // Dec 31st cutoff (DEFAULT)
    case fullTheatricalRun = "full_run"     // Until movie leaves theaters

    var displayName: String {
        switch self {
        case .yearEnd: return "Year-End (Dec 31)"
        case .fullTheatricalRun: return "Full Theatrical Run"
        }
    }

    var description: String {
        switch self {
        case .yearEnd: return "Only counts earnings through December 31st"
        case .fullTheatricalRun: return "Counts all earnings until the movie leaves theaters"
        }
    }
}

// MARK: - Trade Approval Mode

/// How trades are approved in the league
enum TradeApprovalMode: String, Codable, CaseIterable, Sendable {
    case autoAccept = "auto_accept"             // Trades process immediately (DEFAULT)
    case commissionerApproval = "commissioner"  // Commissioner must approve
    case commissionerVeto = "commissioner_veto" // Commissioner can veto within window
    case leagueVote = "league_vote"             // Majority vote required

    var displayName: String {
        switch self {
        case .autoAccept: return "Auto-Accept"
        case .commissionerApproval: return "Commissioner Approval"
        case .commissionerVeto: return "Commissioner Veto Window"
        case .leagueVote: return "League Vote"
        }
    }

    var description: String {
        switch self {
        case .autoAccept: return "Trades complete immediately when both parties agree"
        case .commissionerApproval: return "Commissioner must approve all trades"
        case .commissionerVeto: return "Trades process unless commissioner vetoes within review period"
        case .leagueVote: return "League members vote on trades"
        }
    }

    var icon: String {
        switch self {
        case .autoAccept: return "checkmark.circle.fill"
        case .commissionerApproval: return "person.badge.shield.checkmark.fill"
        case .commissionerVeto: return "hand.raised.fill"
        case .leagueVote: return "person.3.fill"
        }
    }
}

// MARK: - Oscar Draft Style

/// How Oscar picks are drafted
enum OscarDraftStyle: String, Codable, CaseIterable, Sendable {
    case anyCategory = "any_category"       // Pick from any category any round (DEFAULT)
    case categoryRounds = "category_rounds" // Each round is a specific category

    var displayName: String {
        switch self {
        case .anyCategory: return "Any Category"
        case .categoryRounds: return "Category Rounds"
        }
    }

    var description: String {
        switch self {
        case .anyCategory: return "Pick your 'locks' from any category in any order"
        case .categoryRounds: return "Each round focuses on one category; duplicates allowed"
        }
    }
}

// MARK: - Oscar Mode Settings

/// Settings specific to Oscar prediction leagues
struct OscarModeSettings: Codable, Hashable, Sendable {
    /// How picks are drafted
    var draftStyle: OscarDraftStyle

    /// Allow multiple users to pick the same nominee (for category rounds)
    var allowDuplicatePicks: Bool

    /// Lock all picks when the ceremony starts
    var lockAtCeremonyStart: Bool

    /// Allow trades/adds/drops before ceremony
    var allowPreCeremonyMoves: Bool

    /// The Oscar ceremony date
    var ceremonyDate: Date?

    /// Point value per correct pick
    var pointsPerCorrectPick: Double

    /// Bonus points for picking all in a category correctly (category rounds)
    var categoryBonusPoints: Double

    init(
        draftStyle: OscarDraftStyle = .anyCategory,
        allowDuplicatePicks: Bool = false,
        lockAtCeremonyStart: Bool = true,
        allowPreCeremonyMoves: Bool = true,
        ceremonyDate: Date? = nil,
        pointsPerCorrectPick: Double = 1.0,
        categoryBonusPoints: Double = 2.0
    ) {
        self.draftStyle = draftStyle
        self.allowDuplicatePicks = allowDuplicatePicks
        self.lockAtCeremonyStart = lockAtCeremonyStart
        self.allowPreCeremonyMoves = allowPreCeremonyMoves
        self.ceremonyDate = ceremonyDate
        self.pointsPerCorrectPick = pointsPerCorrectPick
        self.categoryBonusPoints = categoryBonusPoints
    }

    /// Fixed Oscar ceremony date for a given Oscar year. Not user-configurable.
    /// 2026 ceremony is March 15, 2026; other years use last Sunday of February as fallback.
    static func ceremonyDate(forOscarYear year: Int) -> Date {
        if year == 2026 {
            var components = DateComponents()
            components.year = 2026
            components.month = 3
            components.day = 15
            return Calendar.current.date(from: components) ?? defaultCeremonyDate(year: year)
        }
        return defaultCeremonyDate(year: year)
    }

    /// Fallback Oscar ceremony date (last Sunday of February) when no fixed date is set.
    private static func defaultCeremonyDate(year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 2
        components.weekday = 1 // Sunday
        components.weekdayOrdinal = -1 // Last occurrence
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Trading Settings

/// Settings for league trading
struct TradingSettings: Codable, Hashable, Sendable {
    /// Whether trading is enabled
    var enabled: Bool

    /// How trades are approved
    var approvalMode: TradeApprovalMode

    /// Hours for trade review (commissioner veto mode)
    var reviewPeriodHours: Int

    /// Maximum movies per side in a trade
    var maxMoviesPerSide: Int

    /// Allow 2-for-1 and 3-for-1 trades
    var allowUnevenTrades: Bool

    /// Trade deadline (nil = no deadline)
    var tradeDeadline: Date?

    init(
        enabled: Bool = true,
        approvalMode: TradeApprovalMode = .autoAccept,
        reviewPeriodHours: Int = 24,
        maxMoviesPerSide: Int = 3,
        allowUnevenTrades: Bool = true,
        tradeDeadline: Date? = nil
    ) {
        self.enabled = enabled
        self.approvalMode = approvalMode
        self.reviewPeriodHours = reviewPeriodHours
        self.maxMoviesPerSide = maxMoviesPerSide
        self.allowUnevenTrades = allowUnevenTrades
        self.tradeDeadline = tradeDeadline
    }
}

// MARK: - Free Agency Settings

/// Settings for free agent pickups and drops
struct FreeAgencySettings: Codable, Hashable, Sendable {
    /// Whether free agency is enabled
    var enabled: Bool

    /// Hours for waiver claims to process
    var waiverPeriodHours: Int

    /// Waiver order type
    var waiverOrder: WaiverOrderType

    /// Whether movies that started showing can be dropped
    var allowDroppingShowingMovies: Bool

    /// Maximum add/drop transactions per week (0 = unlimited)
    var weeklyTransactionLimit: Int

    /// Free agency deadline (nil = no deadline)
    var deadline: Date?

    init(
        enabled: Bool = true,
        waiverPeriodHours: Int = 24,
        waiverOrder: WaiverOrderType = .reverseStandings,
        allowDroppingShowingMovies: Bool = false,
        weeklyTransactionLimit: Int = 0,
        deadline: Date? = nil
    ) {
        self.enabled = enabled
        self.waiverPeriodHours = waiverPeriodHours
        self.waiverOrder = waiverOrder
        self.allowDroppingShowingMovies = allowDroppingShowingMovies
        self.weeklyTransactionLimit = weeklyTransactionLimit
        self.deadline = deadline
    }
}

/// How waiver priority is determined
enum WaiverOrderType: String, Codable, CaseIterable, Sendable {
    case reverseStandings = "reverse_standings" // Worst team gets priority
    case rollingList = "rolling_list"           // Priority rotates after each claim
    case freeForAll = "free_for_all"            // First come, first served

    var displayName: String {
        switch self {
        case .reverseStandings: return "Reverse Standings"
        case .rollingList: return "Rolling Priority"
        case .freeForAll: return "First Come, First Served"
        }
    }
}

// MARK: - Represents a Fantasy Flicks League

struct FFLeague: Codable, Identifiable, Hashable, Sendable {
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

    var isBoxOfficeMode: Bool { settings.leagueMode == .boxOffice }
    var isRottenTomatoesMode: Bool { settings.leagueMode == .rottenTomatoes }
    var isOscarMode: Bool { settings.leagueMode == .oscar }

    var canTrade: Bool {
        guard settings.tradingSettings.enabled else { return false }
        if let deadline = settings.tradingSettings.tradeDeadline {
            return Date() < deadline
        }
        return !isSeasonComplete
    }

    var canPickupFreeAgents: Bool {
        guard settings.freeAgencySettings.enabled else { return false }
        if let deadline = settings.freeAgencySettings.deadline {
            return Date() < deadline
        }
        return !isSeasonComplete
    }

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
struct LeagueSettings: Codable, Hashable, Sendable {

    // MARK: - Core Mode

    /// The primary game mode
    var leagueMode: LeagueMode

    // MARK: - Draft Settings

    /// Type of draft order
    var draftType: DraftType

    /// How draft order is determined
    var draftOrderType: DraftOrderType

    /// Manually set draft order (user IDs in order) - used when draftOrderType is .manual
    var manualDraftOrder: [String]?

    /// Number of movies each player drafts
    var moviesPerPlayer: Int

    /// Seconds allowed per pick (0 = no timer)
    var pickTimerSeconds: Int

    // MARK: - Scoring Settings

    /// How scoring works (for box office and RT modes)
    var scoringMode: ScoringMode

    /// Whether higher or lower scores win
    var scoringDirection: ScoringDirection

    /// When box office scoring ends
    var boxOfficeCutoff: BoxOfficeCutoff

    // MARK: - Trading Settings

    var tradingSettings: TradingSettings

    // MARK: - Free Agency Settings

    var freeAgencySettings: FreeAgencySettings

    // MARK: - Oscar Mode Settings

    var oscarSettings: OscarModeSettings?

    // MARK: - Movie Filters

    var movieFilters: MovieFilterSettings

    // MARK: - Initialization

    init(
        leagueMode: LeagueMode = .boxOffice,
        draftType: DraftType = .serpentine,
        draftOrderType: DraftOrderType = .random,
        manualDraftOrder: [String]? = nil,
        moviesPerPlayer: Int = 5,
        pickTimerSeconds: Int = 300, // 5 minutes default
        scoringMode: ScoringMode = .boxOfficeWorldwide,
        scoringDirection: ScoringDirection = .highest,
        boxOfficeCutoff: BoxOfficeCutoff = .yearEnd,
        tradingSettings: TradingSettings = TradingSettings(),
        freeAgencySettings: FreeAgencySettings = FreeAgencySettings(),
        oscarSettings: OscarModeSettings? = nil,
        movieFilters: MovieFilterSettings = MovieFilterSettings()
    ) {
        self.leagueMode = leagueMode
        self.draftType = draftType
        self.draftOrderType = draftOrderType
        self.manualDraftOrder = manualDraftOrder
        self.moviesPerPlayer = moviesPerPlayer
        self.pickTimerSeconds = pickTimerSeconds
        self.scoringMode = scoringMode
        self.scoringDirection = scoringDirection
        self.boxOfficeCutoff = boxOfficeCutoff
        self.tradingSettings = tradingSettings
        self.freeAgencySettings = freeAgencySettings
        self.oscarSettings = oscarSettings
        self.movieFilters = movieFilters
    }

    // MARK: - Preset Configurations

    /// Default Box Office league settings
    static var boxOfficeDefaults: LeagueSettings {
        LeagueSettings(
            leagueMode: .boxOffice,
            scoringMode: .boxOfficeWorldwide,
            boxOfficeCutoff: .yearEnd
        )
    }

    /// Default Rotten Tomatoes league settings
    static var rottenTomatoesDefaults: LeagueSettings {
        LeagueSettings(
            leagueMode: .rottenTomatoes,
            scoringMode: .ratingsCombined
        )
    }

    /// Default Oscar league settings
    static var oscarDefaults: LeagueSettings {
        LeagueSettings(
            leagueMode: .oscar,
            moviesPerPlayer: 5, // 5 picks
            oscarSettings: OscarModeSettings()
        )
    }
}

// MARK: - Movie Filter Settings

struct MovieFilterSettings: Codable, Hashable, Sendable {
    /// Only include theatrical releases (no streaming-only)
    var theatricalOnly: Bool

    /// Minimum production budget (filters out micro-budget films)
    var minimumBudget: Int?

    /// Exclude specific genres
    var excludedGenreIds: [Int]

    /// Only include movies from specific studios
    var includedStudioIds: [Int]?

    /// Release date range start
    var releaseDateStart: Date?

    /// Release date range end
    var releaseDateEnd: Date?

    init(
        theatricalOnly: Bool = true,
        minimumBudget: Int? = 1_000_000,
        excludedGenreIds: [Int] = [],
        includedStudioIds: [Int]? = nil,
        releaseDateStart: Date? = nil,
        releaseDateEnd: Date? = nil
    ) {
        self.theatricalOnly = theatricalOnly
        self.minimumBudget = minimumBudget
        self.excludedGenreIds = excludedGenreIds
        self.includedStudioIds = includedStudioIds
        self.releaseDateStart = releaseDateStart
        self.releaseDateEnd = releaseDateEnd
    }
}

// MARK: - Enums

enum DraftType: String, Codable, CaseIterable, Sendable {
    case fixed = "fixed"           // Same order every round
    case serpentine = "serpentine" // Snake draft (1-8, 8-1, 1-8...)

    var displayName: String {
        switch self {
        case .fixed: return "Fixed Order"
        case .serpentine: return "Snake Draft"
        }
    }

    var description: String {
        switch self {
        case .fixed: return "Same picking order every round"
        case .serpentine: return "Order reverses each round for fairness"
        }
    }

    var icon: String {
        switch self {
        case .fixed: return "arrow.down"
        case .serpentine: return "arrow.turn.down.right"
        }
    }
}

enum DraftOrderType: String, Codable, CaseIterable, Sendable {
    case random = "random"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .random: return "Randomized"
        case .manual: return "Set Manually"
        }
    }

    var description: String {
        switch self {
        case .random: return "Draft order is randomized when the draft starts"
        case .manual: return "Commissioner sets the draft order"
        }
    }
}

enum ScoringMode: String, Codable, CaseIterable, Sendable {
    case boxOfficeDomestic = "box_office_domestic"
    case boxOfficeWorldwide = "box_office_worldwide"
    case ratingsRT = "ratings_rt"           // Rotten Tomatoes critic
    case ratingsAudience = "ratings_audience" // Audience score
    case ratingsCombined = "ratings_combined" // Average of RT + Audience

    var displayName: String {
        switch self {
        case .boxOfficeDomestic: return "Domestic Box Office"
        case .boxOfficeWorldwide: return "Worldwide Box Office"
        case .ratingsRT: return "Rotten Tomatoes Score"
        case .ratingsAudience: return "Audience Score"
        case .ratingsCombined: return "Combined Ratings"
        }
    }

    var shortName: String {
        switch self {
        case .boxOfficeDomestic: return "Domestic"
        case .boxOfficeWorldwide: return "Worldwide"
        case .ratingsRT: return "RT Score"
        case .ratingsAudience: return "Audience"
        case .ratingsCombined: return "Combined"
        }
    }

    var icon: String {
        switch self {
        case .boxOfficeDomestic, .boxOfficeWorldwide: return "dollarsign.circle.fill"
        case .ratingsRT, .ratingsAudience, .ratingsCombined: return "star.fill"
        }
    }

    var isBoxOffice: Bool {
        switch self {
        case .boxOfficeDomestic, .boxOfficeWorldwide: return true
        default: return false
        }
    }

    var isRatings: Bool {
        switch self {
        case .ratingsRT, .ratingsAudience, .ratingsCombined: return true
        default: return false
        }
    }

    /// Scoring modes available for Box Office league mode
    static var boxOfficeModes: [ScoringMode] {
        [.boxOfficeDomestic, .boxOfficeWorldwide]
    }

    /// Scoring modes available for Rotten Tomatoes league mode
    static var ratingsModes: [ScoringMode] {
        [.ratingsRT, .ratingsAudience, .ratingsCombined]
    }
}

enum ScoringDirection: String, Codable, CaseIterable, Sendable {
    case highest = "highest" // Highest score wins (DEFAULT)
    case lowest = "lowest"   // Lowest score wins (for flops/sleeper leagues)

    var displayName: String {
        switch self {
        case .highest: return "Highest Wins"
        case .lowest: return "Lowest Wins"
        }
    }

    var description: String {
        switch self {
        case .highest: return "Team with the highest total score wins"
        case .lowest: return "Team with the lowest total score wins (find the flops!)"
        }
    }

    var icon: String {
        switch self {
        case .highest: return "arrow.up.circle.fill"
        case .lowest: return "arrow.down.circle.fill"
        }
    }
}

enum DraftStatus: String, Codable, Sendable {
    case pending = "pending"       // Draft not yet started
    case scheduled = "scheduled"   // Draft time set
    case inProgress = "in_progress" // Draft currently happening
    case paused = "paused"         // Draft paused (async)
    case completed = "completed"   // Draft finished

    var displayName: String {
        switch self {
        case .pending: return "Not Scheduled"
        case .scheduled: return "Scheduled"
        case .inProgress: return "Live"
        case .paused: return "Paused"
        case .completed: return "Completed"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "calendar.badge.clock"
        case .scheduled: return "calendar.badge.checkmark"
        case .inProgress: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
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
        settings: .boxOfficeDefaults,
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
            settings: .rottenTomatoesDefaults,
            commissionerId: "user_002",
            memberIds: ["user_002", "user_001"],
            draftStatus: .pending,
            seasonYear: 2026
        ),
        FFLeague(
            id: "league_003",
            name: "Oscar Oracles",
            description: "Predict the Academy Award winners!",
            settings: .oscarDefaults,
            commissionerId: "user_003",
            memberIds: ["user_003", "user_004", "user_001"],
            draftStatus: .inProgress,
            seasonYear: 2026
        ),
        FFLeague(
            id: "league_004",
            name: "Flop Hunters",
            description: "Find the biggest box office bombs!",
            settings: LeagueSettings(
                leagueMode: .boxOffice,
                scoringDirection: .lowest
            ),
            commissionerId: "user_004",
            memberIds: ["user_004", "user_001"],
            draftStatus: .pending,
            seasonYear: 2026
        )
    ]
}
