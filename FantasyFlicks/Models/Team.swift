//
//  Team.swift
//  FantasyFlicks
//
//  Team model - links a user to a league with their drafted movies
//

import Foundation

/// Represents a user's team within a specific league
struct FFTeam: Codable, Identifiable, Hashable {
    let id: String

    /// The league this team belongs to
    let leagueId: String

    /// The user who owns this team
    let userId: String

    /// Custom team name (optional)
    var teamName: String?

    /// IDs of movies drafted by this team
    var movieIds: [String]

    /// Current total score
    var totalScore: Double

    /// Current rank in the league (1 = first place)
    var currentRank: Int?

    /// Score breakdown by movie
    var movieScores: [String: Double] // movieId -> score

    /// Bonus points (from Oscar predictions, etc.)
    var bonusPoints: Double

    // MARK: - Draft Position

    /// This team's position in the draft order
    var draftPosition: Int?

    /// Number of picks this team has made
    var picksMade: Int

    // MARK: - Trade History

    /// IDs of completed trades involving this team
    var tradeIds: [String]

    // MARK: - Metadata

    let joinedAt: Date
    var lastUpdatedAt: Date

    // MARK: - Computed Properties

    var movieCount: Int { movieIds.count }

    var displayName: String {
        teamName ?? "Team \(draftPosition ?? 0)"
    }

    var totalWithBonus: Double {
        totalScore + bonusPoints
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        leagueId: String,
        userId: String,
        teamName: String? = nil,
        movieIds: [String] = [],
        totalScore: Double = 0,
        currentRank: Int? = nil,
        movieScores: [String: Double] = [:],
        bonusPoints: Double = 0,
        draftPosition: Int? = nil,
        picksMade: Int = 0,
        tradeIds: [String] = [],
        joinedAt: Date = Date(),
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.leagueId = leagueId
        self.userId = userId
        self.teamName = teamName
        self.movieIds = movieIds
        self.totalScore = totalScore
        self.currentRank = currentRank
        self.movieScores = movieScores
        self.bonusPoints = bonusPoints
        self.draftPosition = draftPosition
        self.picksMade = picksMade
        self.tradeIds = tradeIds
        self.joinedAt = joinedAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}

// MARK: - Team Standing (for leaderboards)

struct FFTeamStanding: Codable, Identifiable, Hashable {
    var id: String { teamId }

    let teamId: String
    let userId: String
    let teamName: String
    let rank: Int
    let previousRank: Int? // For showing movement
    let totalScore: Double
    let bonusPoints: Double
    let movieCount: Int
    let topMovieTitle: String?
    let topMovieScore: Double?

    var rankChange: Int? {
        guard let previous = previousRank else { return nil }
        return previous - rank // Positive = moved up
    }

    var rankChangeIcon: String? {
        guard let change = rankChange else { return nil }
        if change > 0 { return "arrow.up" }
        if change < 0 { return "arrow.down" }
        return "minus"
    }
}

// MARK: - Sample Data

extension FFTeam {
    static let sample = FFTeam(
        id: "team_001",
        leagueId: "league_001",
        userId: "user_001",
        teamName: "Blockbuster Brigade",
        movieIds: ["movie_001", "movie_002", "movie_003"],
        totalScore: 1_250_000_000,
        currentRank: 1,
        movieScores: [
            "movie_001": 500_000_000,
            "movie_002": 450_000_000,
            "movie_003": 300_000_000
        ],
        bonusPoints: 50_000_000,
        draftPosition: 3,
        picksMade: 3
    )
}

extension FFTeamStanding {
    static let sample = FFTeamStanding(
        teamId: "team_001",
        userId: "user_001",
        teamName: "Blockbuster Brigade",
        rank: 1,
        previousRank: 2,
        totalScore: 1_250_000_000,
        bonusPoints: 50_000_000,
        movieCount: 3,
        topMovieTitle: "Avatar 4",
        topMovieScore: 500_000_000
    )

    static let sampleStandings: [FFTeamStanding] = [
        .sample,
        FFTeamStanding(teamId: "team_002", userId: "user_002", teamName: "Cinema Kings", rank: 2, previousRank: 1, totalScore: 1_100_000_000, bonusPoints: 0, movieCount: 3, topMovieTitle: "Mission: Impossible 9", topMovieScore: 400_000_000),
        FFTeamStanding(teamId: "team_003", userId: "user_003", teamName: "Reel Winners", rank: 3, previousRank: 3, totalScore: 950_000_000, bonusPoints: 25_000_000, movieCount: 3, topMovieTitle: "Jurassic World 4", topMovieScore: 350_000_000),
        FFTeamStanding(teamId: "team_004", userId: "user_004", teamName: "The Projectionists", rank: 4, previousRank: 4, totalScore: 800_000_000, bonusPoints: 0, movieCount: 3, topMovieTitle: "Frozen 3", topMovieScore: 300_000_000)
    ]
}
