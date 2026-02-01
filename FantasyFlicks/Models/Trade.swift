//
//  Trade.swift
//  FantasyFlicks
//
//  Trade model for trading movies between teams
//  Supports multi-movie trades, commissioner veto, and roster drops
//

import Foundation

/// Represents a trade proposal between two teams
struct FFTrade: Codable, Identifiable, Hashable, Sendable {
    let id: String

    /// League this trade is in
    let leagueId: String

    // MARK: - Trade Parties

    /// Team proposing the trade
    let proposingTeamId: String
    let proposingUserId: String
    let proposingTeamName: String?

    /// Team receiving the proposal
    let receivingTeamId: String
    let receivingUserId: String
    let receivingTeamName: String?

    // MARK: - Trade Assets

    /// Movie IDs being offered by proposing team
    var proposingTeamMovieIds: [String]

    /// Movie IDs being requested from receiving team
    var receivingTeamMovieIds: [String]

    /// Cached movie details for display
    var proposingTeamMovies: [TradeMovieInfo]
    var receivingTeamMovies: [TradeMovieInfo]

    // MARK: - Required Drops (for uneven trades)

    /// Movies the proposing team must drop to make room
    var proposingTeamDropIds: [String]

    /// Movies the receiving team must drop to make room
    var receivingTeamDropIds: [String]

    /// Cached drop movie details
    var proposingTeamDrops: [TradeMovieInfo]
    var receivingTeamDrops: [TradeMovieInfo]

    /// Optional message from proposer
    var message: String?

    // MARK: - Trade Status

    var status: TradeStatus

    /// When the trade was proposed
    let proposedAt: Date

    /// When the trade was responded to (accepted/rejected)
    var respondedAt: Date?

    /// When the trade will auto-expire if not responded to
    var expiresAt: Date

    // MARK: - Commissioner Review

    /// When league/commissioner review period ends
    var reviewEndsAt: Date?

    /// Whether commissioner has reviewed
    var commissionerReviewed: Bool

    /// Whether commissioner vetoed the trade
    var commissionerVetoed: Bool

    /// Commissioner's notes (for veto explanation)
    var commissionerNotes: String?

    // MARK: - League Vote (if enabled)

    /// User IDs who have vetoed the trade
    var vetoedByUserIds: [String]

    /// User IDs who have approved the trade
    var approvedByUserIds: [String]

    /// Number of vetoes required to cancel (for league vote mode)
    let vetosRequired: Int

    /// Number of approvals required (for league vote mode)
    let approvalsRequired: Int

    // MARK: - Computed Properties

    var isExpired: Bool {
        Date() > expiresAt && status == .pending
    }

    var isPendingReview: Bool {
        status == .accepted && reviewEndsAt != nil && Date() < reviewEndsAt!
    }

    var vetoCount: Int {
        vetoedByUserIds.count
    }

    var approvalCount: Int {
        approvedByUserIds.count
    }

    var wasVetoed: Bool {
        commissionerVetoed || vetoCount >= vetosRequired
    }

    var wasApprovedByVote: Bool {
        approvalCount >= approvalsRequired
    }

    var canComplete: Bool {
        status == .accepted && !isPendingReview && !wasVetoed
    }

    /// Whether this is an uneven trade (different number of movies)
    var isUnevenTrade: Bool {
        proposingTeamMovieIds.count != receivingTeamMovieIds.count
    }

    /// Net movies for proposing team (positive = receiving more)
    var proposingTeamNetMovies: Int {
        receivingTeamMovieIds.count - proposingTeamMovieIds.count
    }

    /// Net movies for receiving team (positive = receiving more)
    var receivingTeamNetMovies: Int {
        proposingTeamMovieIds.count - receivingTeamMovieIds.count
    }

    /// Human-readable trade summary
    var summary: String {
        let proposingCount = proposingTeamMovieIds.count
        let receivingCount = receivingTeamMovieIds.count

        if proposingCount == 1 && receivingCount == 1 {
            return "1-for-1 Trade"
        } else {
            return "\(proposingCount)-for-\(receivingCount) Trade"
        }
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        leagueId: String,
        proposingTeamId: String,
        proposingUserId: String,
        proposingTeamName: String? = nil,
        receivingTeamId: String,
        receivingUserId: String,
        receivingTeamName: String? = nil,
        proposingTeamMovieIds: [String],
        receivingTeamMovieIds: [String],
        proposingTeamMovies: [TradeMovieInfo] = [],
        receivingTeamMovies: [TradeMovieInfo] = [],
        proposingTeamDropIds: [String] = [],
        receivingTeamDropIds: [String] = [],
        proposingTeamDrops: [TradeMovieInfo] = [],
        receivingTeamDrops: [TradeMovieInfo] = [],
        message: String? = nil,
        status: TradeStatus = .pending,
        proposedAt: Date = Date(),
        respondedAt: Date? = nil,
        expiresAt: Date = Date().addingTimeInterval(86400 * 2), // 2 days
        reviewEndsAt: Date? = nil,
        commissionerReviewed: Bool = false,
        commissionerVetoed: Bool = false,
        commissionerNotes: String? = nil,
        vetoedByUserIds: [String] = [],
        approvedByUserIds: [String] = [],
        vetosRequired: Int = 3,
        approvalsRequired: Int = 3
    ) {
        self.id = id
        self.leagueId = leagueId
        self.proposingTeamId = proposingTeamId
        self.proposingUserId = proposingUserId
        self.proposingTeamName = proposingTeamName
        self.receivingTeamId = receivingTeamId
        self.receivingUserId = receivingUserId
        self.receivingTeamName = receivingTeamName
        self.proposingTeamMovieIds = proposingTeamMovieIds
        self.receivingTeamMovieIds = receivingTeamMovieIds
        self.proposingTeamMovies = proposingTeamMovies
        self.receivingTeamMovies = receivingTeamMovies
        self.proposingTeamDropIds = proposingTeamDropIds
        self.receivingTeamDropIds = receivingTeamDropIds
        self.proposingTeamDrops = proposingTeamDrops
        self.receivingTeamDrops = receivingTeamDrops
        self.message = message
        self.status = status
        self.proposedAt = proposedAt
        self.respondedAt = respondedAt
        self.expiresAt = expiresAt
        self.reviewEndsAt = reviewEndsAt
        self.commissionerReviewed = commissionerReviewed
        self.commissionerVetoed = commissionerVetoed
        self.commissionerNotes = commissionerNotes
        self.vetoedByUserIds = vetoedByUserIds
        self.approvedByUserIds = approvedByUserIds
        self.vetosRequired = vetosRequired
        self.approvalsRequired = approvalsRequired
    }

    // MARK: - Validation

    /// Validates the trade is properly formed
    func validate() -> TradeValidationResult {
        // Check both sides have movies
        if proposingTeamMovieIds.isEmpty {
            return .invalid("Proposing team must offer at least one movie")
        }
        if receivingTeamMovieIds.isEmpty {
            return .invalid("Must request at least one movie")
        }

        // Check max movies per side (typically 3)
        let maxPerSide = 3
        if proposingTeamMovieIds.count > maxPerSide {
            return .invalid("Cannot trade more than \(maxPerSide) movies per side")
        }
        if receivingTeamMovieIds.count > maxPerSide {
            return .invalid("Cannot request more than \(maxPerSide) movies")
        }

        // Check for duplicate movies
        let allMovies = proposingTeamMovieIds + receivingTeamMovieIds
        if Set(allMovies).count != allMovies.count {
            return .invalid("Trade contains duplicate movies")
        }

        // Check drops are specified for uneven trades
        if proposingTeamNetMovies > 0 && proposingTeamDropIds.count != proposingTeamNetMovies {
            return .invalid("Proposing team must drop \(proposingTeamNetMovies) movie(s)")
        }
        if receivingTeamNetMovies > 0 && receivingTeamDropIds.count != receivingTeamNetMovies {
            return .invalid("Receiving team must drop \(receivingTeamNetMovies) movie(s)")
        }

        return .valid
    }
}

/// Result of trade validation
enum TradeValidationResult {
    case valid
    case invalid(String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .invalid(let message) = self { return message }
        return nil
    }
}

/// Movie info cached in trade for display
struct TradeMovieInfo: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let posterPath: String?
    let releaseDate: String?
    let currentScore: Double?

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(path)")
    }

    init(
        id: String,
        title: String,
        posterPath: String? = nil,
        releaseDate: String? = nil,
        currentScore: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.currentScore = currentScore
    }
}

// MARK: - Trade Status

enum TradeStatus: String, Codable, Sendable {
    case pending = "pending"           // Awaiting response from receiving team
    case accepted = "accepted"         // Accepted, may be in review period
    case rejected = "rejected"         // Rejected by receiving team
    case withdrawn = "withdrawn"       // Withdrawn by proposing team
    case expired = "expired"           // No response before expiration
    case vetoed = "vetoed"             // Vetoed by commissioner or league
    case completed = "completed"       // Trade finalized and processed
    case processing = "processing"     // Being processed by system

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        case .withdrawn: return "Withdrawn"
        case .expired: return "Expired"
        case .vetoed: return "Vetoed"
        case .completed: return "Completed"
        case .processing: return "Processing"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .withdrawn: return "arrow.uturn.backward.circle.fill"
        case .expired: return "clock.badge.xmark.fill"
        case .vetoed: return "hand.raised.fill"
        case .completed: return "checkmark.seal.fill"
        case .processing: return "arrow.triangle.2.circlepath"
        }
    }

    var color: String {
        switch self {
        case .pending: return "goldPrimary"
        case .accepted, .completed: return "success"
        case .rejected, .expired, .vetoed: return "ruby"
        case .withdrawn: return "textSecondary"
        case .processing: return "goldPrimary"
        }
    }

    var isActive: Bool {
        switch self {
        case .pending, .accepted, .processing: return true
        default: return false
        }
    }

    var isFinal: Bool {
        switch self {
        case .rejected, .withdrawn, .expired, .vetoed, .completed: return true
        default: return false
        }
    }
}

// MARK: - Trade Notification

struct FFTradeNotification: Codable, Identifiable, Sendable {
    let id: String
    let tradeId: String
    let userId: String
    let type: TradeNotificationType
    let message: String
    let createdAt: Date
    var isRead: Bool

    enum TradeNotificationType: String, Codable, Sendable {
        case proposalReceived = "proposal_received"
        case proposalAccepted = "proposal_accepted"
        case proposalRejected = "proposal_rejected"
        case proposalWithdrawn = "proposal_withdrawn"
        case proposalExpired = "proposal_expired"
        case tradeVetoed = "trade_vetoed"
        case tradeCompleted = "trade_completed"
        case vetoWarning = "veto_warning"
        case reviewStarted = "review_started"
        case counterOffer = "counter_offer"

        var title: String {
            switch self {
            case .proposalReceived: return "Trade Proposal"
            case .proposalAccepted: return "Trade Accepted"
            case .proposalRejected: return "Trade Rejected"
            case .proposalWithdrawn: return "Trade Withdrawn"
            case .proposalExpired: return "Trade Expired"
            case .tradeVetoed: return "Trade Vetoed"
            case .tradeCompleted: return "Trade Completed"
            case .vetoWarning: return "Veto Warning"
            case .reviewStarted: return "Trade Under Review"
            case .counterOffer: return "Counter Offer"
            }
        }

        var icon: String {
            switch self {
            case .proposalReceived: return "arrow.left.arrow.right"
            case .proposalAccepted: return "checkmark.circle.fill"
            case .proposalRejected: return "xmark.circle.fill"
            case .proposalWithdrawn: return "arrow.uturn.backward"
            case .proposalExpired: return "clock.badge.xmark"
            case .tradeVetoed: return "hand.raised.fill"
            case .tradeCompleted: return "checkmark.seal.fill"
            case .vetoWarning: return "exclamationmark.triangle.fill"
            case .reviewStarted: return "eye.fill"
            case .counterOffer: return "arrow.triangle.2.circlepath"
            }
        }
    }
}

// MARK: - Trade Counter Offer

/// A counter-offer to an existing trade
struct FFTradeCounter: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let originalTradeId: String

    /// The original trade's receiving team proposes the counter
    let proposingTeamId: String
    let proposingUserId: String

    /// Modified movie lists
    var proposingTeamMovieIds: [String]
    var receivingTeamMovieIds: [String]

    /// Required drops
    var proposingTeamDropIds: [String]
    var receivingTeamDropIds: [String]

    /// Counter message
    var message: String?

    /// When counter was proposed
    let proposedAt: Date

    /// Status
    var status: TradeStatus

    init(
        id: String = UUID().uuidString,
        originalTradeId: String,
        proposingTeamId: String,
        proposingUserId: String,
        proposingTeamMovieIds: [String],
        receivingTeamMovieIds: [String],
        proposingTeamDropIds: [String] = [],
        receivingTeamDropIds: [String] = [],
        message: String? = nil,
        proposedAt: Date = Date(),
        status: TradeStatus = .pending
    ) {
        self.id = id
        self.originalTradeId = originalTradeId
        self.proposingTeamId = proposingTeamId
        self.proposingUserId = proposingUserId
        self.proposingTeamMovieIds = proposingTeamMovieIds
        self.receivingTeamMovieIds = receivingTeamMovieIds
        self.proposingTeamDropIds = proposingTeamDropIds
        self.receivingTeamDropIds = receivingTeamDropIds
        self.message = message
        self.proposedAt = proposedAt
        self.status = status
    }
}

// MARK: - Sample Data

extension FFTrade {
    static let sample = FFTrade(
        id: "trade_001",
        leagueId: "league_001",
        proposingTeamId: "team_001",
        proposingUserId: "user_001",
        proposingTeamName: "Blockbuster Brigade",
        receivingTeamId: "team_002",
        receivingUserId: "user_002",
        receivingTeamName: "Cinema Kings",
        proposingTeamMovieIds: ["movie_001"],
        receivingTeamMovieIds: ["movie_002"],
        proposingTeamMovies: [
            TradeMovieInfo(id: "movie_001", title: "Avatar 4", currentScore: 500_000_000)
        ],
        receivingTeamMovies: [
            TradeMovieInfo(id: "movie_002", title: "Mission: Impossible 9", currentScore: 400_000_000)
        ],
        message: "I think this is a fair trade - what do you say?",
        status: .pending
    )

    static let sampleUnevenTrade = FFTrade(
        id: "trade_002",
        leagueId: "league_001",
        proposingTeamId: "team_001",
        proposingUserId: "user_001",
        proposingTeamName: "Blockbuster Brigade",
        receivingTeamId: "team_002",
        receivingUserId: "user_002",
        receivingTeamName: "Cinema Kings",
        proposingTeamMovieIds: ["movie_001", "movie_003"],
        receivingTeamMovieIds: ["movie_002"],
        proposingTeamMovies: [
            TradeMovieInfo(id: "movie_001", title: "Avatar 4", currentScore: 500_000_000),
            TradeMovieInfo(id: "movie_003", title: "Jurassic World 4", currentScore: 350_000_000)
        ],
        receivingTeamMovies: [
            TradeMovieInfo(id: "movie_002", title: "Mission: Impossible 9", currentScore: 800_000_000)
        ],
        receivingTeamDropIds: ["movie_drop_001"],
        receivingTeamDrops: [
            TradeMovieInfo(id: "movie_drop_001", title: "Flop Movie")
        ],
        message: "2-for-1: Take the #1 projected movie!",
        status: .pending
    )
}
