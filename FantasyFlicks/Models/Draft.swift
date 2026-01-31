//
//  Draft.swift
//  FantasyFlicks
//
//  Draft and Pick models for the fantasy film draft system
//

import Foundation

/// Represents a draft session for a league
struct FFDraft: Codable, Identifiable, Hashable {
    let id: String

    /// The league this draft belongs to
    let leagueId: String

    // MARK: - Draft Configuration

    /// Type of draft (fixed or serpentine)
    let draftType: DraftType

    /// Ordered list of user IDs representing draft order
    var draftOrder: [String]

    /// Number of rounds (movies per player)
    let totalRounds: Int

    /// Seconds per pick (0 = no timer)
    let pickTimerSeconds: Int

    // MARK: - Draft State

    /// Current status of the draft
    var status: DraftStatus

    /// Current round number (1-indexed)
    var currentRound: Int

    /// Current pick number within the round (1-indexed)
    var currentPickInRound: Int

    /// Overall pick number (1-indexed)
    var currentOverallPick: Int

    /// User ID of the person currently picking
    var currentPickerId: String?

    /// When the current pick timer started (nil if no active timer)
    var pickTimerStartedAt: Date?

    /// All picks made so far
    var picks: [FFDraftPick]

    // MARK: - Timestamps

    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var pausedAt: Date?

    // MARK: - Computed Properties

    var totalPicks: Int {
        draftOrder.count * totalRounds
    }

    var picksRemaining: Int {
        totalPicks - picks.count
    }

    var progressPercentage: Double {
        guard totalPicks > 0 else { return 0 }
        return Double(picks.count) / Double(totalPicks)
    }

    var isComplete: Bool {
        status == .completed || picks.count >= totalPicks
    }

    var isActive: Bool {
        status == .inProgress
    }

    /// Get the picker for a specific overall pick number
    func pickerForPick(_ pickNumber: Int) -> String? {
        guard pickNumber > 0 && pickNumber <= totalPicks else { return nil }

        let round = ((pickNumber - 1) / draftOrder.count) + 1
        let pickInRound = ((pickNumber - 1) % draftOrder.count) + 1

        // For serpentine, reverse order on even rounds
        if draftType == .serpentine && round % 2 == 0 {
            let reversedIndex = draftOrder.count - pickInRound
            return draftOrder[reversedIndex]
        } else {
            return draftOrder[pickInRound - 1]
        }
    }

    /// Get remaining time for current pick in seconds
    func remainingPickTime() -> Int? {
        guard pickTimerSeconds > 0,
              let startTime = pickTimerStartedAt else { return nil }

        let elapsed = Int(Date().timeIntervalSince(startTime))
        return max(0, pickTimerSeconds - elapsed)
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        leagueId: String,
        draftType: DraftType = .serpentine,
        draftOrder: [String],
        totalRounds: Int,
        pickTimerSeconds: Int = 120,
        status: DraftStatus = .pending,
        currentRound: Int = 1,
        currentPickInRound: Int = 1,
        currentOverallPick: Int = 1,
        currentPickerId: String? = nil,
        pickTimerStartedAt: Date? = nil,
        picks: [FFDraftPick] = [],
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        pausedAt: Date? = nil
    ) {
        self.id = id
        self.leagueId = leagueId
        self.draftType = draftType
        self.draftOrder = draftOrder
        self.totalRounds = totalRounds
        self.pickTimerSeconds = pickTimerSeconds
        self.status = status
        self.currentRound = currentRound
        self.currentPickInRound = currentPickInRound
        self.currentOverallPick = currentOverallPick
        self.currentPickerId = currentPickerId ?? draftOrder.first
        self.pickTimerStartedAt = pickTimerStartedAt
        self.picks = picks
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.pausedAt = pausedAt
    }
}

// MARK: - Draft Pick

/// Represents a single pick in the draft
struct FFDraftPick: Codable, Identifiable, Hashable {
    let id: String

    /// The draft this pick belongs to
    let draftId: String

    /// The team/user who made this pick
    let teamId: String
    let userId: String

    /// The movie that was picked
    let movieId: String
    let movieTitle: String
    let moviePosterPath: String?

    // MARK: - Pick Position

    /// Overall pick number (1-indexed)
    let overallPickNumber: Int

    /// Round number (1-indexed)
    let roundNumber: Int

    /// Pick within the round (1-indexed)
    let pickInRound: Int

    // MARK: - Timing

    /// When this pick was made
    let pickedAt: Date

    /// How many seconds the picker took (nil if no timer)
    let secondsTaken: Int?

    /// Whether this was an auto-pick (timer expired)
    let wasAutoPick: Bool

    // MARK: - Computed Properties

    var posterURL: URL? {
        guard let path = moviePosterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(path)")
    }

    var pickLabel: String {
        "Round \(roundNumber), Pick \(pickInRound)"
    }

    var overallLabel: String {
        "#\(overallPickNumber) Overall"
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        draftId: String,
        teamId: String,
        userId: String,
        movieId: String,
        movieTitle: String,
        moviePosterPath: String? = nil,
        overallPickNumber: Int,
        roundNumber: Int,
        pickInRound: Int,
        pickedAt: Date = Date(),
        secondsTaken: Int? = nil,
        wasAutoPick: Bool = false
    ) {
        self.id = id
        self.draftId = draftId
        self.teamId = teamId
        self.userId = userId
        self.movieId = movieId
        self.movieTitle = movieTitle
        self.moviePosterPath = moviePosterPath
        self.overallPickNumber = overallPickNumber
        self.roundNumber = roundNumber
        self.pickInRound = pickInRound
        self.pickedAt = pickedAt
        self.secondsTaken = secondsTaken
        self.wasAutoPick = wasAutoPick
    }
}

// MARK: - Draft Board Cell

/// Represents a cell in the visual draft board
struct FFDraftBoardCell: Identifiable, Hashable {
    var id: String { "\(round)-\(position)" }

    let round: Int
    let position: Int // Position in draft order
    let userId: String
    let pick: FFDraftPick?

    var isEmpty: Bool { pick == nil }
    var overallPickNumber: Int {
        // Calculate based on round and position
        return (round - 1) * 8 + position // Assuming 8 teams
    }
}

// MARK: - Sample Data

extension FFDraft {
    static let sample = FFDraft(
        id: "draft_001",
        leagueId: "league_001",
        draftType: .serpentine,
        draftOrder: ["user_001", "user_002", "user_003", "user_004"],
        totalRounds: 5,
        pickTimerSeconds: 120,
        status: .inProgress,
        currentRound: 2,
        currentPickInRound: 2,
        currentOverallPick: 6,
        currentPickerId: "user_003",
        pickTimerStartedAt: Date(),
        picks: FFDraftPick.samplePicks,
        startedAt: Date().addingTimeInterval(-1800)
    )
}

extension FFDraftPick {
    static let sample = FFDraftPick(
        draftId: "draft_001",
        teamId: "team_001",
        userId: "user_001",
        movieId: "movie_001",
        movieTitle: "Avatar 4",
        moviePosterPath: "/sample.jpg",
        overallPickNumber: 1,
        roundNumber: 1,
        pickInRound: 1,
        secondsTaken: 45
    )

    static let samplePicks: [FFDraftPick] = [
        FFDraftPick(draftId: "draft_001", teamId: "team_001", userId: "user_001", movieId: "movie_001", movieTitle: "Avatar 4", overallPickNumber: 1, roundNumber: 1, pickInRound: 1, secondsTaken: 45),
        FFDraftPick(draftId: "draft_001", teamId: "team_002", userId: "user_002", movieId: "movie_002", movieTitle: "Mission: Impossible 9", overallPickNumber: 2, roundNumber: 1, pickInRound: 2, secondsTaken: 78),
        FFDraftPick(draftId: "draft_001", teamId: "team_003", userId: "user_003", movieId: "movie_003", movieTitle: "Jurassic World 4", overallPickNumber: 3, roundNumber: 1, pickInRound: 3, secondsTaken: 23),
        FFDraftPick(draftId: "draft_001", teamId: "team_004", userId: "user_004", movieId: "movie_004", movieTitle: "Frozen 3", overallPickNumber: 4, roundNumber: 1, pickInRound: 4, secondsTaken: 110),
        FFDraftPick(draftId: "draft_001", teamId: "team_004", userId: "user_004", movieId: "movie_005", movieTitle: "Dune: Part Three", overallPickNumber: 5, roundNumber: 2, pickInRound: 1, secondsTaken: 35)
    ]
}
