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
        OscarCategory(id: "best_casting", name: "Best Casting", shortName: "Casting", order: 9, icon: "person.3.fill", isMajor: false),

        // Animation & International
        OscarCategory(id: "best_animated_feature", name: "Best Animated Feature", shortName: "Animated", order: 10, icon: "sparkles", isMajor: false),
        OscarCategory(id: "best_international_feature", name: "Best International Feature", shortName: "International", order: 11, icon: "globe", isMajor: false),
        OscarCategory(id: "best_documentary_feature", name: "Best Documentary Feature", shortName: "Documentary", order: 12, icon: "doc.richtext.fill", isMajor: false),

        // Technical
        OscarCategory(id: "best_cinematography", name: "Best Cinematography", shortName: "Cinematography", order: 13, icon: "camera.fill", isMajor: false),
        OscarCategory(id: "best_film_editing", name: "Best Film Editing", shortName: "Editing", order: 14, icon: "scissors", isMajor: false),
        OscarCategory(id: "best_production_design", name: "Best Production Design", shortName: "Production", order: 15, icon: "building.2.fill", isMajor: false),
        OscarCategory(id: "best_costume_design", name: "Best Costume Design", shortName: "Costume", order: 16, icon: "tshirt.fill", isMajor: false),
        OscarCategory(id: "best_makeup_hairstyling", name: "Best Makeup and Hairstyling", shortName: "Makeup", order: 17, icon: "paintbrush.fill", isMajor: false),

        // Sound & Music
        OscarCategory(id: "best_sound", name: "Best Sound", shortName: "Sound", order: 18, icon: "speaker.wave.3.fill", isMajor: false),
        OscarCategory(id: "best_original_score", name: "Best Original Score", shortName: "Score", order: 19, icon: "music.note", isMajor: false),
        OscarCategory(id: "best_original_song", name: "Best Original Song", shortName: "Song", order: 20, icon: "music.mic", isMajor: false),

        // Visual Effects
        OscarCategory(id: "best_visual_effects", name: "Best Visual Effects", shortName: "VFX", order: 21, icon: "wand.and.stars", isMajor: false),

        // Shorts
        OscarCategory(id: "best_animated_short", name: "Best Animated Short Film", shortName: "Anim. Short", order: 22, icon: "play.rectangle.fill", isMajor: false),
        OscarCategory(id: "best_live_action_short", name: "Best Live Action Short Film", shortName: "Live Short", order: 23, icon: "play.rectangle.fill", isMajor: false),
        OscarCategory(id: "best_documentary_short", name: "Best Documentary Short Film", shortName: "Doc. Short", order: 24, icon: "play.rectangle.fill", isMajor: false)
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
        source: OddsSource = .expertConsensus,
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
    case expertConsensus = "expert_consensus"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .kalshi: return "Kalshi"
        case .polymarket: return "Polymarket"
        case .goldDerby: return "Gold Derby"
        case .expertConsensus: return "Expert Consensus"
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

// MARK: - 97th Academy Awards Nominees (2025 Ceremony)

extension OscarNominee {

    /// Complete nominee data for the 97th Academy Awards (March 2, 2025)
    /// Covers all 23 categories with full nominee lists
    static let nominees97th: [OscarNominee] = {
        let year = 2025

        // MARK: Best Picture
        let bestPicture: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_picture", name: "Anora", movieId: 1064028),
            OscarNominee(year: year, categoryId: "best_picture", name: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_picture", name: "A Complete Unknown", movieId: 661539),
            OscarNominee(year: year, categoryId: "best_picture", name: "Conclave", movieId: 974453),
            OscarNominee(year: year, categoryId: "best_picture", name: "Dune: Part Two", movieId: 693134),
            OscarNominee(year: year, categoryId: "best_picture", name: "Emilia Pérez", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_picture", name: "I'm Still Here", movieId: 1084199),
            OscarNominee(year: year, categoryId: "best_picture", name: "Nickel Boys", movieId: 1015607),
            OscarNominee(year: year, categoryId: "best_picture", name: "The Substance", movieId: 933260),
            OscarNominee(year: year, categoryId: "best_picture", name: "Wicked", movieId: 402431),
        ]

        // MARK: Best Director
        let bestDirector: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_director", name: "Sean Baker", movieTitle: "Anora", movieId: 1064028),
            OscarNominee(year: year, categoryId: "best_director", name: "Brady Corbet", movieTitle: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_director", name: "James Mangold", movieTitle: "A Complete Unknown", movieId: 661539),
            OscarNominee(year: year, categoryId: "best_director", name: "Jacques Audiard", movieTitle: "Emilia Pérez", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_director", name: "Coralie Fargeat", movieTitle: "The Substance", movieId: 933260),
        ]

        // MARK: Best Actor
        let bestActor: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_actor", name: "Adrien Brody", movieTitle: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_actor", name: "Timothée Chalamet", movieTitle: "A Complete Unknown", movieId: 661539),
            OscarNominee(year: year, categoryId: "best_actor", name: "Colman Domingo", movieTitle: "Sing Sing", movieId: 1029281),
            OscarNominee(year: year, categoryId: "best_actor", name: "Ralph Fiennes", movieTitle: "Conclave", movieId: 974453),
            OscarNominee(year: year, categoryId: "best_actor", name: "Sebastian Stan", movieTitle: "The Apprentice", movieId: 985939),
        ]

        // MARK: Best Actress
        let bestActress: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_actress", name: "Cynthia Erivo", movieTitle: "Wicked", movieId: 402431),
            OscarNominee(year: year, categoryId: "best_actress", name: "Karla Sofía Gascón", movieTitle: "Emilia Pérez", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_actress", name: "Mikey Madison", movieTitle: "Anora", movieId: 1064028),
            OscarNominee(year: year, categoryId: "best_actress", name: "Demi Moore", movieTitle: "The Substance", movieId: 933260),
            OscarNominee(year: year, categoryId: "best_actress", name: "Fernanda Torres", movieTitle: "I'm Still Here", movieId: 1084199),
        ]

        // MARK: Best Supporting Actor
        let bestSupportingActor: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Yura Borisov", movieTitle: "Anora", movieId: 1064028),
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Kieran Culkin", movieTitle: "A Real Pain", movieId: 1010581),
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Edward Norton", movieTitle: "A Complete Unknown", movieId: 661539),
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Guy Pearce", movieTitle: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Jeremy Strong", movieTitle: "The Apprentice", movieId: 985939),
        ]

        // MARK: Best Supporting Actress
        let bestSupportingActress: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Monica Barbaro", movieTitle: "A Complete Unknown", movieId: 661539),
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Ariana Grande", movieTitle: "Wicked", movieId: 402431),
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Felicity Jones", movieTitle: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Isabella Rossellini", movieTitle: "Conclave", movieId: 974453),
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Zoe Saldaña", movieTitle: "Emilia Pérez", movieId: 974950),
        ]

        // MARK: Best Original Screenplay
        let bestOriginalScreenplay: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Sean Baker", movieTitle: "Anora", movieId: 1064028),
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Brady Corbet & Mona Fastvold", movieTitle: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Jesse Eisenberg", movieTitle: "A Real Pain", movieId: 1010581),
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Moritz Binder & Tim Fehlbaum", movieTitle: "September 5", movieId: 1029575),
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Coralie Fargeat", movieTitle: "The Substance", movieId: 933260),
        ]

        // MARK: Best Adapted Screenplay
        let bestAdaptedScreenplay: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "James Mangold & Jay Cocks", movieTitle: "A Complete Unknown", movieId: 661539),
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "Peter Straughan", movieTitle: "Conclave", movieId: 974453),
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "Jacques Audiard", movieTitle: "Emilia Pérez", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "RaMell Ross & Joslyn Barnes", movieTitle: "Nickel Boys", movieId: 1015607),
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "Clint Bentley & Greg Kwedar", movieTitle: "Sing Sing", movieId: 1029281),
        ]

        // MARK: Best Animated Feature
        let bestAnimatedFeature: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "Flow", movieId: 823219),
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "Inside Out 2", movieId: 1022789),
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "Memoir of a Snail", movieId: 1139817),
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "Wallace & Gromit: Vengeance Most Fowl", movieId: 959092),
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "The Wild Robot", movieId: 1184918),
        ]

        // MARK: Best International Feature Film
        let bestInternationalFeature: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_international_feature", name: "I'm Still Here", movieTitle: "Brazil", movieId: 1084199),
            OscarNominee(year: year, categoryId: "best_international_feature", name: "The Girl with the Needle", movieTitle: "Denmark", movieId: 1064486),
            OscarNominee(year: year, categoryId: "best_international_feature", name: "Emilia Pérez", movieTitle: "France", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_international_feature", name: "The Seed of the Sacred Fig", movieTitle: "Germany", movieId: 1090753),
            OscarNominee(year: year, categoryId: "best_international_feature", name: "Flow", movieTitle: "Latvia", movieId: 823219),
        ]

        // MARK: Best Documentary Feature
        let bestDocumentaryFeature: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "Black Box Diaries"),
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "No Other Land"),
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "Porcelain War"),
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "Soundtrack to a Coup d'État"),
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "Sugarcane"),
        ]

        // MARK: Best Cinematography
        let bestCinematography: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Lol Crawley", movieTitle: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Greig Fraser", movieTitle: "Dune: Part Two", movieId: 693134),
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Paul Guilhaume", movieTitle: "Emilia Pérez", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Ed Lachman", movieTitle: "Maria", movieId: 840705),
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Jarin Blaschke", movieTitle: "Nosferatu", movieId: 426063),
        ]

        // MARK: Best Film Editing
        let bestFilmEditing: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_film_editing", name: "Anora", movieId: 1064028),
            OscarNominee(year: year, categoryId: "best_film_editing", name: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_film_editing", name: "Conclave", movieId: 974453),
            OscarNominee(year: year, categoryId: "best_film_editing", name: "Emilia Pérez", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_film_editing", name: "Wicked", movieId: 402431),
        ]

        // MARK: Best Production Design
        let bestProductionDesign: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_production_design", name: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_production_design", name: "Conclave", movieId: 974453),
            OscarNominee(year: year, categoryId: "best_production_design", name: "Dune: Part Two", movieId: 693134),
            OscarNominee(year: year, categoryId: "best_production_design", name: "Nosferatu", movieId: 426063),
            OscarNominee(year: year, categoryId: "best_production_design", name: "Wicked", movieId: 402431),
        ]

        // MARK: Best Costume Design
        let bestCostumeDesign: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_costume_design", name: "A Complete Unknown", movieId: 661539),
            OscarNominee(year: year, categoryId: "best_costume_design", name: "Conclave", movieId: 974453),
            OscarNominee(year: year, categoryId: "best_costume_design", name: "Gladiator II", movieId: 558449),
            OscarNominee(year: year, categoryId: "best_costume_design", name: "Nosferatu", movieId: 426063),
            OscarNominee(year: year, categoryId: "best_costume_design", name: "Wicked", movieId: 402431),
        ]

        // MARK: Best Makeup and Hairstyling
        let bestMakeupHairstyling: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "A Different Man", movieId: 840430),
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "Emilia Pérez", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "Nosferatu", movieId: 426063),
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "The Substance", movieId: 933260),
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "Wicked", movieId: 402431),
        ]

        // MARK: Best Sound
        let bestSound: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_sound", name: "A Complete Unknown", movieId: 661539),
            OscarNominee(year: year, categoryId: "best_sound", name: "Dune: Part Two", movieId: 693134),
            OscarNominee(year: year, categoryId: "best_sound", name: "Emilia Pérez", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_sound", name: "Wicked", movieId: 402431),
            OscarNominee(year: year, categoryId: "best_sound", name: "The Wild Robot", movieId: 1184918),
        ]

        // MARK: Best Original Score
        let bestOriginalScore: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_original_score", name: "Daniel Blumberg", movieTitle: "The Brutalist", movieId: 549509),
            OscarNominee(year: year, categoryId: "best_original_score", name: "Volker Bertelmann", movieTitle: "Conclave", movieId: 974453),
            OscarNominee(year: year, categoryId: "best_original_score", name: "Clément Ducol & Camille", movieTitle: "Emilia Pérez", movieId: 974950),
            OscarNominee(year: year, categoryId: "best_original_score", name: "John Powell & Stephen Schwartz", movieTitle: "Wicked", movieId: 402431),
            OscarNominee(year: year, categoryId: "best_original_score", name: "Kris Bowers", movieTitle: "The Wild Robot", movieId: 1184918),
        ]

        // MARK: Best Original Song
        let bestOriginalSong: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"El Mal\"", movieTitle: "Emilia Pérez", movieId: 974950, details: "Music & Lyrics by Clément Ducol, Camille, Jacques Audiard"),
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"The Journey\"", movieTitle: "The Six Triple Eight", details: "Music & Lyrics by Diane Warren"),
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"Like a Bird\"", movieTitle: "Sing Sing", movieId: 1029281, details: "Music & Lyrics by Abraham Alexander, Adrian Quesada"),
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"Mi Camino\"", movieTitle: "Emilia Pérez", movieId: 974950, details: "Music & Lyrics by Clément Ducol, Camille"),
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"Never Too Late\"", movieTitle: "Elton John: Never Too Late", details: "Music & Lyrics by Elton John, Brandi Carlile"),
        ]

        // MARK: Best Visual Effects
        let bestVisualEffects: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "Alien: Romulus", movieId: 945961),
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "Better Man", movieId: 554729),
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "Dune: Part Two", movieId: 693134),
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "Kingdom of the Planet of the Apes", movieId: 653346),
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "Wicked", movieId: 402431),
        ]

        // MARK: Best Animated Short Film
        let bestAnimatedShort: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_animated_short", name: "Beautiful Men"),
            OscarNominee(year: year, categoryId: "best_animated_short", name: "In the Shadow of the Cypress"),
            OscarNominee(year: year, categoryId: "best_animated_short", name: "Magic Candies"),
            OscarNominee(year: year, categoryId: "best_animated_short", name: "Wander to Wonder"),
            OscarNominee(year: year, categoryId: "best_animated_short", name: "Yuck!"),
        ]

        // MARK: Best Live Action Short Film
        let bestLiveActionShort: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "A Lien"),
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "Anuja"),
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "I'm Not a Robot"),
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "The Last Ranger"),
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "The Man Who Could Not Remain Silent"),
        ]

        // MARK: Best Documentary Short Film
        let bestDocumentaryShort: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "Death by Numbers"),
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "I Am Ready, Warden"),
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "Incident"),
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "Instruments of a Beating Heart"),
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "The Only Girl in the Orchestra"),
        ]

        return bestPicture + bestDirector + bestActor + bestActress
            + bestSupportingActor + bestSupportingActress
            + bestOriginalScreenplay + bestAdaptedScreenplay
            + bestAnimatedFeature + bestInternationalFeature
            + bestDocumentaryFeature + bestCinematography
            + bestFilmEditing + bestProductionDesign
            + bestCostumeDesign + bestMakeupHairstyling
            + bestSound + bestOriginalScore + bestOriginalSong
            + bestVisualEffects + bestAnimatedShort
            + bestLiveActionShort + bestDocumentaryShort
    }()

    // MARK: - 98th Academy Awards Nominees (2026 Ceremony)

    /// Complete nominee data for the 98th Academy Awards (March 15, 2026)
    /// Films of 2025; includes Best Casting (new category).
    static let nominees98th: [OscarNominee] = {
        let year = 2026

        // MARK: Best Picture (movieIds for TMDB poster fetch)
        let bestPicture: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_picture", name: "Bugonia", movieId: 701387),
            OscarNominee(year: year, categoryId: "best_picture", name: "F1", movieId: 911430),
            OscarNominee(year: year, categoryId: "best_picture", name: "Frankenstein", movieId: 1062722),
            OscarNominee(year: year, categoryId: "best_picture", name: "Hamnet", movieId: 858024),
            OscarNominee(year: year, categoryId: "best_picture", name: "Marty Supreme", movieId: 1317288),
            OscarNominee(year: year, categoryId: "best_picture", name: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_picture", name: "The Secret Agent", movieId: 1220564),
            OscarNominee(year: year, categoryId: "best_picture", name: "Sentimental Value", movieId: 1124566),
            OscarNominee(year: year, categoryId: "best_picture", name: "Sinners", movieId: 1233413),
            OscarNominee(year: year, categoryId: "best_picture", name: "Train Dreams", movieId: 1241983),
        ]

        // MARK: Best Director
        let bestDirector: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_director", name: "Chloé Zhao", movieTitle: "Hamnet", movieId: 858024),
            OscarNominee(year: year, categoryId: "best_director", name: "Josh Safdie", movieTitle: "Marty Supreme", movieId: 1317288),
            OscarNominee(year: year, categoryId: "best_director", name: "Paul Thomas Anderson", movieTitle: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_director", name: "Joachim Trier", movieTitle: "Sentimental Value", movieId: 1124566),
            OscarNominee(year: year, categoryId: "best_director", name: "Ryan Coogler", movieTitle: "Sinners", movieId: 1233413),
        ]

        // MARK: Best Actor
        let bestActor: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_actor", name: "Timothée Chalamet", movieTitle: "Marty Supreme", movieId: 1317288),
            OscarNominee(year: year, categoryId: "best_actor", name: "Leonardo DiCaprio", movieTitle: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_actor", name: "Ethan Hawke", movieTitle: "Blue Moon", movieId: 1299655),
            OscarNominee(year: year, categoryId: "best_actor", name: "Michael B. Jordan", movieTitle: "Sinners", movieId: 1233413),
            OscarNominee(year: year, categoryId: "best_actor", name: "Wagner Moura", movieTitle: "The Secret Agent", movieId: 1220564),
        ]

        // MARK: Best Actress
        let bestActress: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_actress", name: "Jessie Buckley", movieTitle: "Hamnet", movieId: 858024),
            OscarNominee(year: year, categoryId: "best_actress", name: "Rose Byrne", movieTitle: "If I Had Legs I'd Kick You", movieId: 1160360),
            OscarNominee(year: year, categoryId: "best_actress", name: "Kate Hudson", movieTitle: "Song Sung Blue", movieId: 1371185),
            OscarNominee(year: year, categoryId: "best_actress", name: "Renate Reinsve", movieTitle: "Sentimental Value", movieId: 1124566),
            OscarNominee(year: year, categoryId: "best_actress", name: "Emma Stone", movieTitle: "Bugonia", movieId: 701387),
        ]

        // MARK: Best Supporting Actor
        let bestSupportingActor: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Benicio del Toro", movieTitle: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Jacob Elordi", movieTitle: "Frankenstein", movieId: 1062722),
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Delroy Lindo", movieTitle: "Sinners", movieId: 1233413),
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Sean Penn", movieTitle: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_supporting_actor", name: "Stellan Skarsgård", movieTitle: "Sentimental Value", movieId: 1124566),
        ]

        // MARK: Best Supporting Actress
        let bestSupportingActress: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Elle Fanning", movieTitle: "Sentimental Value", movieId: 1124566),
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Inga Ibsdotter Lilleaas", movieTitle: "Sentimental Value", movieId: 1124566),
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Amy Madigan", movieTitle: "Weapons", movieId: 1078605),
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Wunmi Mosaku", movieTitle: "Sinners", movieId: 1233413),
            OscarNominee(year: year, categoryId: "best_supporting_actress", name: "Teyana Taylor", movieTitle: "One Battle After Another", movieId: 1054867),
        ]

        // MARK: Best Original Screenplay
        let bestOriginalScreenplay: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Robert Kaplow", movieTitle: "Blue Moon", movieId: 1299655),
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Jafar Panahi", movieTitle: "It Was Just an Accident", movieId: 1456349),
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Ronald Bronstein & Josh Safdie", movieTitle: "Marty Supreme", movieId: 1317288),
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Eskil Vogt & Joachim Trier", movieTitle: "Sentimental Value", movieId: 1124566),
            OscarNominee(year: year, categoryId: "best_original_screenplay", name: "Ryan Coogler", movieTitle: "Sinners", movieId: 1233413),
        ]

        // MARK: Best Adapted Screenplay
        let bestAdaptedScreenplay: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "Will Tracy", movieTitle: "Bugonia", movieId: 701387),
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "Guillermo del Toro", movieTitle: "Frankenstein", movieId: 1062722),
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "Chloé Zhao & Maggie O'Farrell", movieTitle: "Hamnet", movieId: 858024),
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "Paul Thomas Anderson", movieTitle: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_adapted_screenplay", name: "Clint Bentley & Greg Kwedar", movieTitle: "Train Dreams", movieId: 1241983),
        ]

        // MARK: Best Casting (98th – new category)
        let bestCasting: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_casting", name: "Nina Gold", movieTitle: "Hamnet", movieId: 858024),
            OscarNominee(year: year, categoryId: "best_casting", name: "Jennifer Venditti", movieTitle: "Marty Supreme", movieId: 1317288),
            OscarNominee(year: year, categoryId: "best_casting", name: "Cassandra Kulukundis", movieTitle: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_casting", name: "Gabriel Domingues", movieTitle: "The Secret Agent", movieId: 1220564),
            OscarNominee(year: year, categoryId: "best_casting", name: "Francine Maisler", movieTitle: "Sinners", movieId: 1233413),
        ]

        // MARK: Best Animated Feature
        let bestAnimatedFeature: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "Arco", movieId: 804370),
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "Elio", movieId: 1022787),
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "KPop Demon Hunters", movieId: 803796),
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "Little Amélie or the Character of Rain"),
            OscarNominee(year: year, categoryId: "best_animated_feature", name: "Zootopia 2", movieId: 1084242),
        ]

        // MARK: Best International Feature Film
        let bestInternationalFeature: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_international_feature", name: "It Was Just an Accident", movieTitle: "France", movieId: 1456349),
            OscarNominee(year: year, categoryId: "best_international_feature", name: "The Secret Agent", movieTitle: "Brazil", movieId: 1220564),
            OscarNominee(year: year, categoryId: "best_international_feature", name: "Sentimental Value", movieTitle: "Norway", movieId: 1124566),
            OscarNominee(year: year, categoryId: "best_international_feature", name: "Sirāt", movieTitle: "Spain"),
            OscarNominee(year: year, categoryId: "best_international_feature", name: "The Voice of Hind Rajab", movieTitle: "Tunisia"),
        ]

        // MARK: Best Documentary Feature
        let bestDocumentaryFeature: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "The Alabama Solution"),
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "Come See Me in the Good Light"),
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "Cutting Through Rocks"),
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "Mr Nobody Against Putin"),
            OscarNominee(year: year, categoryId: "best_documentary_feature", name: "The Perfect Neighbor"),
        ]

        // MARK: Best Cinematography
        let bestCinematography: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Dan Laustsen", movieTitle: "Frankenstein", movieId: 1062722),
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Darius Khondji", movieTitle: "Marty Supreme", movieId: 1317288),
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Michael Bauman", movieTitle: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Autumn Durald Arkapaw", movieTitle: "Sinners", movieId: 1233413),
            OscarNominee(year: year, categoryId: "best_cinematography", name: "Adolpho Veloso", movieTitle: "Train Dreams", movieId: 1241983),
        ]

        // MARK: Best Film Editing
        let bestFilmEditing: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_film_editing", name: "F1", movieId: 911430),
            OscarNominee(year: year, categoryId: "best_film_editing", name: "Marty Supreme", movieId: 1317288),
            OscarNominee(year: year, categoryId: "best_film_editing", name: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_film_editing", name: "Sentimental Value", movieId: 1124566),
            OscarNominee(year: year, categoryId: "best_film_editing", name: "Sinners", movieId: 1233413),
        ]

        // MARK: Best Production Design
        let bestProductionDesign: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_production_design", name: "Frankenstein", movieId: 1062722),
            OscarNominee(year: year, categoryId: "best_production_design", name: "Hamnet", movieId: 858024),
            OscarNominee(year: year, categoryId: "best_production_design", name: "Marty Supreme", movieId: 1317288),
            OscarNominee(year: year, categoryId: "best_production_design", name: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_production_design", name: "Sinners", movieId: 1233413),
        ]

        // MARK: Best Costume Design
        let bestCostumeDesign: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_costume_design", name: "Avatar: Fire and Ash", movieId: 83533),
            OscarNominee(year: year, categoryId: "best_costume_design", name: "Frankenstein", movieId: 1062722),
            OscarNominee(year: year, categoryId: "best_costume_design", name: "Hamnet", movieId: 858024),
            OscarNominee(year: year, categoryId: "best_costume_design", name: "Marty Supreme", movieId: 1317288),
            OscarNominee(year: year, categoryId: "best_costume_design", name: "Sinners", movieId: 1233413),
        ]

        // MARK: Best Makeup and Hairstyling
        let bestMakeupHairstyling: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "Frankenstein", movieId: 1062722),
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "Kokuho"),
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "Sinners", movieId: 1233413),
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "The Smashing Machine", movieId: 760329),
            OscarNominee(year: year, categoryId: "best_makeup_hairstyling", name: "The Ugly Stepsister"),
        ]

        // MARK: Best Sound
        let bestSound: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_sound", name: "F1", movieId: 911430),
            OscarNominee(year: year, categoryId: "best_sound", name: "Frankenstein", movieId: 1062722),
            OscarNominee(year: year, categoryId: "best_sound", name: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_sound", name: "Sinners", movieId: 1233413),
            OscarNominee(year: year, categoryId: "best_sound", name: "Sirāt"),
        ]

        // MARK: Best Original Score
        let bestOriginalScore: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_original_score", name: "Jerskin Fendrix", movieTitle: "Bugonia", movieId: 701387),
            OscarNominee(year: year, categoryId: "best_original_score", name: "Alexandre Desplat", movieTitle: "Frankenstein", movieId: 1062722),
            OscarNominee(year: year, categoryId: "best_original_score", name: "Max Richter", movieTitle: "Hamnet", movieId: 858024),
            OscarNominee(year: year, categoryId: "best_original_score", name: "Jonny Greenwood", movieTitle: "One Battle After Another", movieId: 1054867),
            OscarNominee(year: year, categoryId: "best_original_score", name: "Ludwig Göransson", movieTitle: "Sinners", movieId: 1233413),
        ]

        // MARK: Best Original Song
        let bestOriginalSong: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"Dear Me\"", movieTitle: "Diane Warren: Relentless", details: "Music & Lyrics by Diane Warren"),
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"Golden\"", movieTitle: "KPop Demon Hunters", movieId: 803796, details: "Music & Lyrics by Ejae, Mark Sonnenblick, Ido, Teddy Park"),
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"I Lied to You\"", movieTitle: "Sinners", movieId: 1233413, details: "Music & Lyrics by Raphael Saadiq, Ludwig Göransson"),
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"Sweet Dreams of Joy\"", movieTitle: "Viva Verdi!", details: "Music & Lyrics by Nicholas Pike"),
            OscarNominee(year: year, categoryId: "best_original_song", name: "\"Train Dreams\"", movieTitle: "Train Dreams", movieId: 1241983, details: "Music by Nick Cave, Bryce Dessner; Lyrics by Nick Cave"),
        ]

        // MARK: Best Visual Effects
        let bestVisualEffects: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "Avatar: Fire and Ash", movieId: 83533),
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "F1", movieId: 911430),
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "Jurassic World Rebirth", movieId: 1234821),
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "The Lost Bus", movieId: 1236470),
            OscarNominee(year: year, categoryId: "best_visual_effects", name: "Sinners", movieId: 1233413),
        ]

        // MARK: Best Animated Short Film
        let bestAnimatedShort: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_animated_short", name: "Butterfly"),
            OscarNominee(year: year, categoryId: "best_animated_short", name: "Forevergreen"),
            OscarNominee(year: year, categoryId: "best_animated_short", name: "The Girl Who Cried Pearls"),
            OscarNominee(year: year, categoryId: "best_animated_short", name: "Retirement Plan"),
            OscarNominee(year: year, categoryId: "best_animated_short", name: "The Three Sisters"),
        ]

        // MARK: Best Live Action Short Film
        let bestLiveActionShort: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "Butcher's Stain"),
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "A Friend of Dorothy"),
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "Jane Austen's Period Drama"),
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "The Singers"),
            OscarNominee(year: year, categoryId: "best_live_action_short", name: "Two People Exchanging Saliva"),
        ]

        // MARK: Best Documentary Short Film
        let bestDocumentaryShort: [OscarNominee] = [
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "All the Empty Rooms"),
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "Armed Only with a Camera: The Life and Death of Brent Renaud"),
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "Children No More: \"Were and Are Gone\""),
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "The Devil Is Busy"),
            OscarNominee(year: year, categoryId: "best_documentary_short", name: "Perfectly a Strangeness"),
        ]

        return bestPicture + bestDirector + bestActor + bestActress
            + bestSupportingActor + bestSupportingActress
            + bestOriginalScreenplay + bestAdaptedScreenplay
            + bestCasting
            + bestAnimatedFeature + bestInternationalFeature
            + bestDocumentaryFeature + bestCinematography
            + bestFilmEditing + bestProductionDesign
            + bestCostumeDesign + bestMakeupHairstyling
            + bestSound + bestOriginalScore + bestOriginalSong
            + bestVisualEffects + bestAnimatedShort
            + bestLiveActionShort + bestDocumentaryShort
    }()

    /// Current ceremony nominees (98th Academy Awards – March 2026). Use for Kalshi and app default.
    static let sampleNominees = nominees98th
}

// MARK: - Expert Consensus Odds (Pre-Ceremony)

extension OscarNominee {

    /// Win probabilities - overwritten at runtime with live Kalshi prediction market data.
    /// Fallback estimates for 98th Academy Awards (March 2026) when Kalshi is unavailable.
    static var expertOdds: [String: Double] = [
        // Best Picture (98th – Sinners leads with 16 noms)
        "Sinners_best_picture": 0.28,
        "One Battle After Another_best_picture": 0.22,
        "Bugonia_best_picture": 0.18,
        "Sentimental Value_best_picture": 0.12,
        "Marty Supreme_best_picture": 0.08,
        "Hamnet_best_picture": 0.05,
        "Frankenstein_best_picture": 0.04,
        "F1_best_picture": 0.02,
        "The Secret Agent_best_picture": 0.01,
        "Train Dreams_best_picture": 0.01,

        // Best Director
        "Ryan Coogler_best_director": 0.35,
        "Paul Thomas Anderson_best_director": 0.25,
        "Chloé Zhao_best_director": 0.20,
        "Joachim Trier_best_director": 0.12,
        "Josh Safdie_best_director": 0.08,

        // Best Actor
        "Timothée Chalamet_best_actor": 0.32,
        "Michael B. Jordan_best_actor": 0.28,
        "Leonardo DiCaprio_best_actor": 0.20,
        "Wagner Moura_best_actor": 0.12,
        "Ethan Hawke_best_actor": 0.08,

        // Best Actress
        "Emma Stone_best_actress": 0.35,
        "Jessie Buckley_best_actress": 0.25,
        "Renate Reinsve_best_actress": 0.20,
        "Kate Hudson_best_actress": 0.12,
        "Rose Byrne_best_actress": 0.08,

        // Best Supporting Actor
        "Jacob Elordi_best_supporting_actor": 0.30,
        "Benicio del Toro_best_supporting_actor": 0.25,
        "Delroy Lindo_best_supporting_actor": 0.22,
        "Stellan Skarsgård_best_supporting_actor": 0.13,
        "Sean Penn_best_supporting_actor": 0.10,

        // Best Supporting Actress
        "Wunmi Mosaku_best_supporting_actress": 0.28,
        "Elle Fanning_best_supporting_actress": 0.24,
        "Teyana Taylor_best_supporting_actress": 0.20,
        "Amy Madigan_best_supporting_actress": 0.15,
        "Inga Ibsdotter Lilleaas_best_supporting_actress": 0.13,

        // Best Original Screenplay
        "Ryan Coogler_best_original_screenplay": 0.35,
        "Eskil Vogt & Joachim Trier_best_original_screenplay": 0.25,
        "Ronald Bronstein & Josh Safdie_best_original_screenplay": 0.20,
        "Robert Kaplow_best_original_screenplay": 0.12,
        "Jafar Panahi_best_original_screenplay": 0.08,

        // Best Adapted Screenplay
        "Paul Thomas Anderson_best_adapted_screenplay": 0.30,
        "Chloé Zhao & Maggie O'Farrell_best_adapted_screenplay": 0.25,
        "Guillermo del Toro_best_adapted_screenplay": 0.20,
        "Will Tracy_best_adapted_screenplay": 0.15,
        "Clint Bentley & Greg Kwedar_best_adapted_screenplay": 0.10,

        // Best Casting
        "Francine Maisler_best_casting": 0.30,
        "Nina Gold_best_casting": 0.25,
        "Cassandra Kulukundis_best_casting": 0.22,
        "Jennifer Venditti_best_casting": 0.13,
        "Gabriel Domingues_best_casting": 0.10,

        // Best Animated Feature
        "Zootopia 2_best_animated_feature": 0.35,
        "Elio_best_animated_feature": 0.25,
        "KPop Demon Hunters_best_animated_feature": 0.20,
        "Arco_best_animated_feature": 0.12,
        "Little Amélie or the Character of Rain_best_animated_feature": 0.08,

        // Best International Feature Film
        "Sentimental Value_best_international_feature": 0.30,
        "The Secret Agent_best_international_feature": 0.25,
        "It Was Just an Accident_best_international_feature": 0.22,
        "Sirāt_best_international_feature": 0.13,
        "The Voice of Hind Rajab_best_international_feature": 0.10,

        // Best Cinematography
        "Autumn Durald Arkapaw_best_cinematography": 0.30,
        "Darius Khondji_best_cinematography": 0.25,
        "Dan Laustsen_best_cinematography": 0.22,
        "Michael Bauman_best_cinematography": 0.13,
        "Adolpho Veloso_best_cinematography": 0.10,

        // Best Visual Effects
        "Sinners_best_visual_effects": 0.35,
        "F1_best_visual_effects": 0.25,
        "Avatar: Fire and Ash_best_visual_effects": 0.20,
        "Jurassic World Rebirth_best_visual_effects": 0.12,
        "The Lost Bus_best_visual_effects": 0.08,

        // Best Original Score
        "Ludwig Göransson_best_original_score": 0.35,
        "Jonny Greenwood_best_original_score": 0.25,
        "Max Richter_best_original_score": 0.20,
        "Alexandre Desplat_best_original_score": 0.12,
        "Jerskin Fendrix_best_original_score": 0.08,

        // Best Original Song
        "\"I Lied to You\"_best_original_song": 0.32,
        "\"Golden\"_best_original_song": 0.25,
        "\"Train Dreams\"_best_original_song": 0.20,
        "\"Dear Me\"_best_original_song": 0.13,
        "\"Sweet Dreams of Joy\"_best_original_song": 0.10,
    ]

    /// Get the expert consensus odds for this nominee
    var odds: Double? {
        OscarNominee.expertOdds["\(name)_\(categoryId)"]
    }

    /// Formatted odds string (e.g., "35%")
    var oddsString: String? {
        guard let odds = odds else { return nil }
        return "\(Int(odds * 100))%"
    }

    /// Whether this nominee is the frontrunner in their category
    var isFrontrunner: Bool {
        guard let myOdds = odds else { return false }
        let categoryNominees = OscarNominee.nominees98th.filter { $0.categoryId == categoryId }
        let maxOdds = categoryNominees.compactMap { $0.odds }.max() ?? 0
        return myOdds == maxOdds
    }
}

// MARK: - Sample Data

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
