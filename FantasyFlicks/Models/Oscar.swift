//
//  Oscar.swift
//  FantasyFlicks
//
//  Models for Oscar prediction mode
//  Categories, nominees, picks, and odds tracking
//

import Foundation

// MARK: - Oscar Category

/// Represents an Oscar award category
struct OscarCategory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let shortName: String
    let order: Int  // Display order
    let icon: String
    let isMajor: Bool  // Major categories (Picture, Director, Acting)

    /// All standard Oscar categories
    static let allCategories: [OscarCategory] = [
        // Major Categories
        OscarCategory(id: "best_picture", name: "Best Picture", shortName: "Picture", order: 1, icon: "film.fill", isMajor: true),
        OscarCategory(id: "best_director", name: "Best Director", shortName: "Director", order: 2, icon: "video.fill", isMajor: true),
        OscarCategory(id: "best_actor", name: "Best Actor", shortName: "Actor", order: 3, icon: "person.fill", isMajor: true),
        OscarCategory(id: "best_actress", name: "Best Actress", shortName: "Actress", order: 4, icon: "person.fill", isMajor: true),
        OscarCategory(id: "best_supporting_actor", name: "Best Supporting Actor", shortName: "Sup. Actor", order: 5, icon: "person.2.fill", isMajor: true),
        OscarCategory(id: "best_supporting_actress", name: "Best Supporting Actress", shortName: "Sup. Actress", order: 6, icon: "person.2.fill", isMajor: true),

        // Writing
        OscarCategory(id: "best_original_screenplay", name: "Best Original Screenplay", shortName: "Orig. Screenplay", order: 7, icon: "doc.text.fill", isMajor: false),
        OscarCategory(id: "best_adapted_screenplay", name: "Best Adapted Screenplay", shortName: "Adpt. Screenplay", order: 8, icon: "doc.text.fill", isMajor: false),

        // Animation & International
        OscarCategory(id: "best_animated_feature", name: "Best Animated Feature", shortName: "Animated", order: 9, icon: "sparkles", isMajor: false),
        OscarCategory(id: "best_international_feature", name: "Best International Feature", shortName: "International", order: 10, icon: "globe", isMajor: false),
        OscarCategory(id: "best_documentary_feature", name: "Best Documentary Feature", shortName: "Documentary", order: 11, icon: "doc.richtext.fill", isMajor: false),

        // Technical
        OscarCategory(id: "best_cinematography", name: "Best Cinematography", shortName: "Cinematography", order: 12, icon: "camera.fill", isMajor: false),
        OscarCategory(id: "best_film_editing", name: "Best Film Editing", shortName: "Editing", order: 13, icon: "scissors", isMajor: false),
        OscarCategory(id: "best_production_design", name: "Best Production Design", shortName: "Production", order: 14, icon: "building.2.fill", isMajor: false),
        OscarCategory(id: "best_costume_design", name: "Best Costume Design", shortName: "Costume", order: 15, icon: "tshirt.fill", isMajor: false),
        OscarCategory(id: "best_makeup_hairstyling", name: "Best Makeup and Hairstyling", shortName: "Makeup", order: 16, icon: "paintbrush.fill", isMajor: false),

        // Sound & Music
        OscarCategory(id: "best_sound", name: "Best Sound", shortName: "Sound", order: 17, icon: "speaker.wave.3.fill", isMajor: false),
        OscarCategory(id: "best_original_score", name: "Best Original Score", shortName: "Score", order: 18, icon: "music.note", isMajor: false),
        OscarCategory(id: "best_original_song", name: "Best Original Song", shortName: "Song", order: 19, icon: "music.mic", isMajor: false),

        // Visual Effects
        OscarCategory(id: "best_visual_effects", name: "Best Visual Effects", shortName: "VFX", order: 20, icon: "wand.and.stars", isMajor: false),

        // Shorts
        OscarCategory(id: "best_animated_short", name: "Best Animated Short Film", shortName: "Anim. Short", order: 21, icon: "play.rectangle.fill", isMajor: false),
        OscarCategory(id: "best_live_action_short", name: "Best Live Action Short Film", shortName: "Live Short", order: 22, icon: "play.rectangle.fill", isMajor: false),
        OscarCategory(id: "best_documentary_short", name: "Best Documentary Short Film", shortName: "Doc. Short", order: 23, icon: "play.rectangle.fill", isMajor: false)
    ]

    /// Major categories only (the "Big 6")
    static var majorCategories: [OscarCategory] {
        allCategories.filter { $0.isMajor }
    }

    /// Get category by ID
    static func category(for id: String) -> OscarCategory? {
        allCategories.first { $0.id == id }
    }
}

// MARK: - Oscar Nominee

/// Represents a nominee in an Oscar category
struct OscarNominee: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let year: Int
    let categoryId: String

    /// Name of the nominee (person or film title)
    let name: String

    /// For acting/directing: the movie title
    let movieTitle: String?

    /// TMDB movie ID (if applicable)
    let movieId: Int?

    /// Poster path for the movie
    let posterPath: String?

    /// Additional details (e.g., song name for Best Song)
    let details: String?

    /// Whether this nominee won
    var isWinner: Bool

    /// When winner was announced
    var winnerAnnouncedAt: Date?

    // MARK: - Computed Properties

    var displayName: String {
        if let movie = movieTitle, !movie.isEmpty {
            return "\(name) - \(movie)"
        }
        return name
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(path)")
    }

    var category: OscarCategory? {
        OscarCategory.category(for: categoryId)
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        year: Int,
        categoryId: String,
        name: String,
        movieTitle: String? = nil,
        movieId: Int? = nil,
        posterPath: String? = nil,
        details: String? = nil,
        isWinner: Bool = false,
        winnerAnnouncedAt: Date? = nil
    ) {
        self.id = id
        self.year = year
        self.categoryId = categoryId
        self.name = name
        self.movieTitle = movieTitle
        self.movieId = movieId
        self.posterPath = posterPath
        self.details = details
        self.isWinner = isWinner
        self.winnerAnnouncedAt = winnerAnnouncedAt
    }
}

// MARK: - Oscar Pick

/// A user's pick for an Oscar category
struct OscarPick: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let leagueId: String
    let teamId: String
    let userId: String

    /// The category this pick is for
    let categoryId: String

    /// The nominee picked
    let nomineeId: String

    /// Cached nominee name for display
    let nomineeName: String

    /// Cached movie title (if applicable)
    let movieTitle: String?

    /// When this pick was made
    let pickedAt: Date

    /// Whether this pick was correct (nil until results announced)
    var isCorrect: Bool?

    /// Points earned for this pick
    var pointsEarned: Double?

    // MARK: - Computed Properties

    var category: OscarCategory? {
        OscarCategory.category(for: categoryId)
    }

    var isPending: Bool {
        isCorrect == nil
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        leagueId: String,
        teamId: String,
        userId: String,
        categoryId: String,
        nomineeId: String,
        nomineeName: String,
        movieTitle: String? = nil,
        pickedAt: Date = Date(),
        isCorrect: Bool? = nil,
        pointsEarned: Double? = nil
    ) {
        self.id = id
        self.leagueId = leagueId
        self.teamId = teamId
        self.userId = userId
        self.categoryId = categoryId
        self.nomineeId = nomineeId
        self.nomineeName = nomineeName
        self.movieTitle = movieTitle
        self.pickedAt = pickedAt
        self.isCorrect = isCorrect
        self.pointsEarned = pointsEarned
    }
}

// MARK: - Oscar Odds

/// Betting odds for an Oscar nominee (from Kalshi or other sources)
struct OscarOdds: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(nomineeId)_\(fetchedAt.timeIntervalSince1970)" }

    let nomineeId: String
    let categoryId: String

    /// Probability of winning (0.0 to 1.0)
    let probability: Double

    /// Raw odds string (e.g., "-150", "+300")
    let oddsString: String?

    /// Source of the odds
    let source: OddsSource

    /// When these odds were fetched
    let fetchedAt: Date

    // MARK: - Computed Properties

    /// Percentage display (e.g., "73%")
    var percentageString: String {
        "\(Int(probability * 100))%"
    }

    /// Whether this is the favorite in the category
    var isFavorite: Bool {
        probability >= 0.5
    }

    // MARK: - Initialization

    init(
        nomineeId: String,
        categoryId: String,
        probability: Double,
        oddsString: String? = nil,
        source: OddsSource = .kalshi,
        fetchedAt: Date = Date()
    ) {
        self.nomineeId = nomineeId
        self.categoryId = categoryId
        self.probability = min(1.0, max(0.0, probability))
        self.oddsString = oddsString
        self.source = source
        self.fetchedAt = fetchedAt
    }
}

/// Source of odds data
enum OddsSource: String, Codable, Sendable {
    case kalshi = "kalshi"
    case polymarket = "polymarket"
    case goldDerby = "gold_derby"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .kalshi: return "Kalshi"
        case .polymarket: return "Polymarket"
        case .goldDerby: return "Gold Derby"
        case .manual: return "Manual"
        }
    }
}

// MARK: - Oscar Standings

/// Team standings for an Oscar league
struct OscarStanding: Codable, Identifiable, Hashable, Sendable {
    var id: String { teamId }

    let teamId: String
    let userId: String
    let teamName: String

    /// Current rank
    var rank: Int

    /// Previous rank (for movement indicator)
    var previousRank: Int?

    /// Total correct picks
    var correctPicks: Int

    /// Total picks made
    var totalPicks: Int

    /// Total points earned
    var totalPoints: Double

    /// Potential max points (if all remaining picks correct)
    var maxPossiblePoints: Double?

    // MARK: - Computed Properties

    var accuracy: Double {
        guard totalPicks > 0 else { return 0 }
        return Double(correctPicks) / Double(totalPicks)
    }

    var accuracyString: String {
        "\(Int(accuracy * 100))%"
    }

    var rankChange: Int? {
        guard let previous = previousRank else { return nil }
        return previous - rank
    }

    var rankChangeIcon: String? {
        guard let change = rankChange else { return nil }
        if change > 0 { return "arrow.up" }
        if change < 0 { return "arrow.down" }
        return "minus"
    }
}

// MARK: - Oscar Year Data

/// All Oscar data for a specific year
struct OscarYearData: Codable, Identifiable, Sendable {
    var id: Int { year }

    let year: Int
    var ceremonyDate: Date?
    var nominationsAnnouncedDate: Date?

    /// All nominees for this year
    var nominees: [OscarNominee]

    /// Whether ceremony has happened
    var ceremonyComplete: Bool

    // MARK: - Helpers

    /// Get nominees for a specific category
    func nominees(for categoryId: String) -> [OscarNominee] {
        nominees.filter { $0.categoryId == categoryId }
    }

    /// Get winner for a category (if announced)
    func winner(for categoryId: String) -> OscarNominee? {
        nominees.first { $0.categoryId == categoryId && $0.isWinner }
    }

    /// Check if category has been announced
    func isCategoryAnnounced(_ categoryId: String) -> Bool {
        nominees.contains { $0.categoryId == categoryId && $0.isWinner }
    }

    /// Categories that haven't been announced yet
    var pendingCategories: [OscarCategory] {
        OscarCategory.allCategories.filter { !isCategoryAnnounced($0.id) }
    }

    /// Categories that have been announced
    var announcedCategories: [OscarCategory] {
        OscarCategory.allCategories.filter { isCategoryAnnounced($0.id) }
    }
}

// MARK: - Oscar Roster Percentage

/// Tracks how many teams have picked a specific nominee
struct OscarRosterPercentage: Codable, Identifiable, Sendable {
    var id: String { "\(nomineeId)_\(leagueId ?? "global")" }

    let nomineeId: String
    let categoryId: String
    let leagueId: String?  // nil for global stats

    /// Number of teams that have picked this nominee
    var pickedCount: Int

    /// Total number of teams
    var totalTeams: Int

    /// Last updated
    var updatedAt: Date

    // MARK: - Computed Properties

    var percentage: Double {
        guard totalTeams > 0 else { return 0 }
        return Double(pickedCount) / Double(totalTeams)
    }

    var percentageString: String {
        "\(Int(percentage * 100))%"
    }

    var popularityTier: PopularityTier {
        switch percentage {
        case 0.75...: return .veryPopular
        case 0.50..<0.75: return .popular
        case 0.25..<0.50: return .moderate
        case 0.10..<0.25: return .sleeper
        default: return .rare
        }
    }
}

/// How popular a pick is
enum PopularityTier: String, Codable, Sendable {
    case veryPopular = "very_popular"  // 75%+
    case popular = "popular"            // 50-75%
    case moderate = "moderate"          // 25-50%
    case sleeper = "sleeper"            // 10-25%
    case rare = "rare"                  // <10%

    var displayName: String {
        switch self {
        case .veryPopular: return "Very Popular"
        case .popular: return "Popular"
        case .moderate: return "Moderate"
        case .sleeper: return "Sleeper"
        case .rare: return "Rare Pick"
        }
    }

    var color: String {
        switch self {
        case .veryPopular: return "ruby"
        case .popular: return "warning"
        case .moderate: return "goldPrimary"
        case .sleeper: return "success"
        case .rare: return "textSecondary"
        }
    }
}

// MARK: - Sample Data

extension OscarNominee {
    static let sampleNominees: [OscarNominee] = [
        // Best Picture
        OscarNominee(year: 2026, categoryId: "best_picture", name: "The Brutalist", movieId: 1, posterPath: nil, isWinner: false),
        OscarNominee(year: 2026, categoryId: "best_picture", name: "Anora", movieId: 2, posterPath: nil, isWinner: false),
        OscarNominee(year: 2026, categoryId: "best_picture", name: "Conclave", movieId: 3, posterPath: nil, isWinner: false),
        OscarNominee(year: 2026, categoryId: "best_picture", name: "Emilia Pérez", movieId: 4, posterPath: nil, isWinner: false),
        OscarNominee(year: 2026, categoryId: "best_picture", name: "Wicked", movieId: 5, posterPath: nil, isWinner: false),

        // Best Actor
        OscarNominee(year: 2026, categoryId: "best_actor", name: "Adrien Brody", movieTitle: "The Brutalist", movieId: 1),
        OscarNominee(year: 2026, categoryId: "best_actor", name: "Timothée Chalamet", movieTitle: "A Complete Unknown", movieId: 6),
        OscarNominee(year: 2026, categoryId: "best_actor", name: "Ralph Fiennes", movieTitle: "Conclave", movieId: 3),

        // Best Actress
        OscarNominee(year: 2026, categoryId: "best_actress", name: "Demi Moore", movieTitle: "The Substance", movieId: 7),
        OscarNominee(year: 2026, categoryId: "best_actress", name: "Mikey Madison", movieTitle: "Anora", movieId: 2),
        OscarNominee(year: 2026, categoryId: "best_actress", name: "Cynthia Erivo", movieTitle: "Wicked", movieId: 5)
    ]
}

extension OscarPick {
    static let sample = OscarPick(
        leagueId: "league_001",
        teamId: "team_001",
        userId: "user_001",
        categoryId: "best_picture",
        nomineeId: "nominee_001",
        nomineeName: "The Brutalist"
    )
}

extension OscarStanding {
    static let sampleStandings: [OscarStanding] = [
        OscarStanding(teamId: "team_001", userId: "user_001", teamName: "Oscar Oracles", rank: 1, previousRank: 2, correctPicks: 4, totalPicks: 5, totalPoints: 4.0),
        OscarStanding(teamId: "team_002", userId: "user_002", teamName: "Academy Aces", rank: 2, previousRank: 1, correctPicks: 3, totalPicks: 5, totalPoints: 3.0),
        OscarStanding(teamId: "team_003", userId: "user_003", teamName: "Golden Guessers", rank: 3, previousRank: 3, correctPicks: 2, totalPicks: 5, totalPoints: 2.0)
    ]
}
