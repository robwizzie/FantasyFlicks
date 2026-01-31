//
//  Trade.swift
//  FantasyFlicks
//
//  Trade model for future trading functionality
//

import Foundation

/// Represents a trade proposal between two teams
struct FFTrade: Codable, Identifiable, Hashable {
    let id: String

    /// League this trade is in
    let leagueId: String

    // MARK: - Trade Parties

    /// Team proposing the trade
    let proposingTeamId: String
    let proposingUserId: String

    /// Team receiving the proposal
    let receivingTeamId: String
    let receivingUserId: String

    // MARK: - Trade Assets

    /// Movie IDs being offered by proposing team
    var proposingTeamMovieIds: [String]

    /// Movie IDs being requested from receiving team
    var receivingTeamMovieIds: [String]

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

    /// When league review period ends (for veto)
    var reviewEndsAt: Date?

    /// User IDs who have vetoed the trade
    var vetoedByUserIds: [String]

    /// Number of vetoes required to cancel
    let vetosRequired: Int

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

    var wasVetoed: Bool {
        vetoCount >= vetosRequired
    }

    var canComplete: Bool {
        status == .accepted && !isPendingReview && !wasVetoed
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        leagueId: String,
        proposingTeamId: String,
        proposingUserId: String,
        receivingTeamId: String,
        receivingUserId: String,
        proposingTeamMovieIds: [String],
        receivingTeamMovieIds: [String],
        message: String? = nil,
        status: TradeStatus = .pending,
        proposedAt: Date = Date(),
        respondedAt: Date? = nil,
        expiresAt: Date = Date().addingTimeInterval(86400 * 2), // 2 days
        reviewEndsAt: Date? = nil,
        vetoedByUserIds: [String] = [],
        vetosRequired: Int = 3
    ) {
        self.id = id
        self.leagueId = leagueId
        self.proposingTeamId = proposingTeamId
        self.proposingUserId = proposingUserId
        self.receivingTeamId = receivingTeamId
        self.receivingUserId = receivingUserId
        self.proposingTeamMovieIds = proposingTeamMovieIds
        self.receivingTeamMovieIds = receivingTeamMovieIds
        self.message = message
        self.status = status
        self.proposedAt = proposedAt
        self.respondedAt = respondedAt
        self.expiresAt = expiresAt
        self.reviewEndsAt = reviewEndsAt
        self.vetoedByUserIds = vetoedByUserIds
        self.vetosRequired = vetosRequired
    }
}

// MARK: - Trade Status

enum TradeStatus: String, Codable {
    case pending = "pending"         // Awaiting response from receiving team
    case accepted = "accepted"       // Accepted, in review period
    case rejected = "rejected"       // Rejected by receiving team
    case withdrawn = "withdrawn"     // Withdrawn by proposing team
    case expired = "expired"         // No response before expiration
    case vetoed = "vetoed"          // Vetoed by league members
    case completed = "completed"     // Trade finalized

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        case .withdrawn: return "Withdrawn"
        case .expired: return "Expired"
        case .vetoed: return "Vetoed"
        case .completed: return "Completed"
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
        }
    }
}

// MARK: - Trade Notification

struct FFTradeNotification: Codable, Identifiable {
    let id: String
    let tradeId: String
    let userId: String
    let type: TradeNotificationType
    let message: String
    let createdAt: Date
    var isRead: Bool

    enum TradeNotificationType: String, Codable {
        case proposalReceived = "proposal_received"
        case proposalAccepted = "proposal_accepted"
        case proposalRejected = "proposal_rejected"
        case proposalWithdrawn = "proposal_withdrawn"
        case proposalExpired = "proposal_expired"
        case tradeVetoed = "trade_vetoed"
        case tradeCompleted = "trade_completed"
        case vetoWarning = "veto_warning"
    }
}

// MARK: - Sample Data

extension FFTrade {
    static let sample = FFTrade(
        id: "trade_001",
        leagueId: "league_001",
        proposingTeamId: "team_001",
        proposingUserId: "user_001",
        receivingTeamId: "team_002",
        receivingUserId: "user_002",
        proposingTeamMovieIds: ["movie_001"],
        receivingTeamMovieIds: ["movie_002"],
        message: "I think this is a fair trade - what do you say?",
        status: .pending
    )
}
