//
//  Notification.swift
//  FantasyFlicks
//
//  In-app notification model for alerts, updates, and activity
//

import Foundation

/// Represents an in-app notification
struct FFNotification: Codable, Identifiable, Hashable, Sendable {
    let id: String

    /// User receiving this notification
    let userId: String

    // MARK: - Content

    let type: NotificationType
    let title: String
    let message: String

    /// Optional deep link path (e.g., "league/123/draft")
    let deepLink: String?

    /// Related entity IDs for context
    let relatedLeagueId: String?
    let relatedDraftId: String?
    let relatedMovieId: String?
    let relatedTradeId: String?

    // MARK: - State

    var isRead: Bool
    var isArchived: Bool

    // MARK: - Timestamps

    let createdAt: Date
    var readAt: Date?

    // MARK: - Computed Properties

    var icon: String {
        type.icon
    }

    var accentColor: String {
        type.accentColor
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        userId: String,
        type: NotificationType,
        title: String,
        message: String,
        deepLink: String? = nil,
        relatedLeagueId: String? = nil,
        relatedDraftId: String? = nil,
        relatedMovieId: String? = nil,
        relatedTradeId: String? = nil,
        isRead: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        readAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.message = message
        self.deepLink = deepLink
        self.relatedLeagueId = relatedLeagueId
        self.relatedDraftId = relatedDraftId
        self.relatedMovieId = relatedMovieId
        self.relatedTradeId = relatedTradeId
        self.isRead = isRead
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.readAt = readAt
    }
}

// MARK: - Notification Type

enum NotificationType: String, Codable, Sendable {
    // Draft notifications
    case draftStartingSoon = "draft_starting_soon"
    case draftStarted = "draft_started"
    case yourTurnToPick = "your_turn_to_pick"
    case pickMade = "pick_made"
    case draftCompleted = "draft_completed"

    // League notifications
    case leagueInvite = "league_invite"
    case memberJoined = "member_joined"
    case memberLeft = "member_left"
    case leagueSettingsChanged = "league_settings_changed"

    // Score notifications
    case scoreUpdated = "score_updated"
    case rankChanged = "rank_changed"
    case seasonEnded = "season_ended"

    // Movie notifications
    case movieReleased = "movie_released"
    case boxOfficeUpdate = "box_office_update"
    case ratingsAvailable = "ratings_available"

    // Trade notifications
    case tradeProposed = "trade_proposed"
    case tradeAccepted = "trade_accepted"
    case tradeRejected = "trade_rejected"
    case tradeCompleted = "trade_completed"

    // Achievement notifications
    case achievementUnlocked = "achievement_unlocked"

    // System notifications
    case systemAnnouncement = "system_announcement"
    case maintenanceScheduled = "maintenance_scheduled"

    var icon: String {
        switch self {
        case .draftStartingSoon, .draftStarted: return "clock.fill"
        case .yourTurnToPick: return "hand.point.right.fill"
        case .pickMade: return "checkmark.circle.fill"
        case .draftCompleted: return "flag.checkered"
        case .leagueInvite: return "envelope.fill"
        case .memberJoined: return "person.badge.plus"
        case .memberLeft: return "person.badge.minus"
        case .leagueSettingsChanged: return "gearshape.fill"
        case .scoreUpdated: return "chart.line.uptrend.xyaxis"
        case .rankChanged: return "trophy.fill"
        case .seasonEnded: return "star.fill"
        case .movieReleased: return "film.fill"
        case .boxOfficeUpdate: return "dollarsign.circle.fill"
        case .ratingsAvailable: return "star.circle.fill"
        case .tradeProposed, .tradeAccepted, .tradeRejected, .tradeCompleted: return "arrow.left.arrow.right"
        case .achievementUnlocked: return "medal.fill"
        case .systemAnnouncement: return "megaphone.fill"
        case .maintenanceScheduled: return "wrench.and.screwdriver.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .yourTurnToPick, .draftStartingSoon: return "ruby"
        case .achievementUnlocked, .rankChanged, .draftCompleted: return "goldPrimary"
        case .tradeProposed, .leagueInvite: return "info"
        case .memberLeft, .tradeRejected: return "textSecondary"
        case .maintenanceScheduled: return "warning"
        default: return "goldPrimary"
        }
    }

    var priority: Int {
        switch self {
        case .yourTurnToPick: return 100
        case .draftStartingSoon, .draftStarted: return 90
        case .tradeProposed: return 80
        case .achievementUnlocked: return 70
        default: return 50
        }
    }
}

// MARK: - Sample Data

extension FFNotification {
    static let sample = FFNotification(
        userId: "user_001",
        type: .yourTurnToPick,
        title: "It's Your Turn!",
        message: "You have 2 minutes to make your pick in Box Office Champions.",
        deepLink: "league/league_001/draft",
        relatedLeagueId: "league_001",
        relatedDraftId: "draft_001"
    )

    static let sampleNotifications: [FFNotification] = [
        .sample,
        FFNotification(
            userId: "user_001",
            type: .achievementUnlocked,
            title: "Achievement Unlocked!",
            message: "You earned 'First Draft Pick' for completing your first draft.",
            createdAt: Date().addingTimeInterval(-3600)
        ),
        FFNotification(
            userId: "user_001",
            type: .boxOfficeUpdate,
            title: "Box Office Update",
            message: "Avatar 4 earned $45M this weekend. Your score increased!",
            relatedMovieId: "movie_001",
            createdAt: Date().addingTimeInterval(-86400)
        ),
        FFNotification(
            userId: "user_001",
            type: .leagueInvite,
            title: "League Invitation",
            message: "MovieGuru invited you to join 'Critics Corner'.",
            relatedLeagueId: "league_002",
            createdAt: Date().addingTimeInterval(-172800)
        )
    ]
}
