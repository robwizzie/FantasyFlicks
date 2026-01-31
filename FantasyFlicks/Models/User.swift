//
//  User.swift
//  FantasyFlicks
//
//  User model representing a Fantasy Flicks player
//

import Foundation

/// Represents a user/player in Fantasy Flicks
struct FFUser: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var username: String
    var displayName: String
    var email: String
    var avatarURL: URL?

    // MARK: - Profile Stats

    /// Total number of leagues participated in
    var totalLeagues: Int

    /// Number of leagues won
    var leaguesWon: Int

    /// Total number of movies drafted across all leagues
    var totalMoviesDrafted: Int

    /// All-time best single movie score
    var bestMovieScore: Double?

    /// User's all-time ranking points (for global leaderboard)
    var rankingPoints: Int

    // MARK: - Achievements

    /// Unlocked achievement IDs
    var achievementIds: [String]

    // MARK: - Preferences

    var notificationsEnabled: Bool
    var draftReminderMinutes: Int // How many minutes before draft to remind

    // MARK: - Social

    /// Friend user IDs
    var friendIds: [String]

    /// Blocked user IDs
    var blockedUserIds: [String]

    // MARK: - Metadata

    let createdAt: Date
    var lastActiveAt: Date

    // MARK: - Computed Properties

    var winRate: Double {
        guard totalLeagues > 0 else { return 0 }
        return Double(leaguesWon) / Double(totalLeagues)
    }

    var winRatePercentage: String {
        return String(format: "%.1f%%", winRate * 100)
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        email: String,
        avatarURL: URL? = nil,
        totalLeagues: Int = 0,
        leaguesWon: Int = 0,
        totalMoviesDrafted: Int = 0,
        bestMovieScore: Double? = nil,
        rankingPoints: Int = 0,
        achievementIds: [String] = [],
        notificationsEnabled: Bool = true,
        draftReminderMinutes: Int = 30,
        friendIds: [String] = [],
        blockedUserIds: [String] = [],
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.avatarURL = avatarURL
        self.totalLeagues = totalLeagues
        self.leaguesWon = leaguesWon
        self.totalMoviesDrafted = totalMoviesDrafted
        self.bestMovieScore = bestMovieScore
        self.rankingPoints = rankingPoints
        self.achievementIds = achievementIds
        self.notificationsEnabled = notificationsEnabled
        self.draftReminderMinutes = draftReminderMinutes
        self.friendIds = friendIds
        self.blockedUserIds = blockedUserIds
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
}

// MARK: - Achievement Model

/// Represents an unlockable achievement
struct FFAchievement: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let iconName: String // SF Symbol name
    let category: AchievementCategory
    let pointsRequired: Int?
    let isSecret: Bool

    enum AchievementCategory: String, Codable, Sendable {
        case drafting    // Draft-related achievements
        case winning     // Victory achievements
        case social      // Friend/league achievements
        case prediction  // Oscar/prediction achievements
        case streak      // Streak-based achievements
        case special     // Limited-time or special achievements
    }
}

// MARK: - Sample Data

extension FFUser {
    static let sample = FFUser(
        id: "user_001",
        username: "filmfanatic",
        displayName: "Film Fanatic",
        email: "fan@example.com",
        totalLeagues: 12,
        leaguesWon: 4,
        totalMoviesDrafted: 87,
        bestMovieScore: 1250.5,
        rankingPoints: 4520,
        achievementIds: ["first_draft", "winning_streak_3", "oscar_prophet"]
    )

    static let sampleUsers: [FFUser] = [
        .sample,
        FFUser(id: "user_002", username: "movieguru", displayName: "Movie Guru", email: "guru@example.com", totalLeagues: 8, leaguesWon: 2),
        FFUser(id: "user_003", username: "boxofficeboss", displayName: "Box Office Boss", email: "boss@example.com", totalLeagues: 15, leaguesWon: 6),
        FFUser(id: "user_004", username: "criticsChoice", displayName: "Critics Choice", email: "critic@example.com", totalLeagues: 5, leaguesWon: 1)
    ]
}
