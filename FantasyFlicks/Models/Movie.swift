//
//  Movie.swift
//  FantasyFlicks
//
//  Movie model with TMDB data, box office, and ratings
//

import Foundation

/// Represents a movie available for drafting or already drafted
struct FFMovie: Codable, Identifiable, Hashable {
    let id: String

    /// TMDB movie ID for API lookups
    let tmdbId: Int

    // MARK: - Basic Info

    var title: String
    var originalTitle: String?
    var tagline: String?
    var overview: String

    // MARK: - Media

    /// Poster image path (append to TMDB base URL)
    var posterPath: String?

    /// Backdrop image path
    var backdropPath: String?

    /// YouTube trailer key
    var trailerKey: String?

    // MARK: - Release Info

    var releaseDate: Date?
    var status: MovieStatus // Rumored, Planned, In Production, Post Production, Released

    /// Runtime in minutes
    var runtime: Int?

    // MARK: - Classification

    var genres: [Genre]
    var genreIds: [Int]

    /// MPAA rating (G, PG, PG-13, R, NC-17)
    var certification: String?

    /// Original language code
    var originalLanguage: String

    // MARK: - Production

    var productionCompanies: [ProductionCompany]
    var budget: Int?

    // MARK: - Cast & Crew

    var cast: [CastMember]
    var crew: [CrewMember]

    var director: String? {
        crew.first { $0.job == "Director" }?.name
    }

    var topBilledCast: [CastMember] {
        Array(cast.prefix(5))
    }

    // MARK: - Scores & Performance

    var boxOffice: BoxOfficeData?
    var ratings: RatingData?

    /// Whether this movie has been released and has final box office numbers
    var hasOfficialNumbers: Bool

    // MARK: - Draft Info

    /// Whether this movie is available to be drafted
    var isDraftable: Bool

    /// ID of the team that drafted this movie (nil if undrafted)
    var draftedByTeamId: String?

    /// Which round this movie was drafted in
    var draftRound: Int?

    /// Which pick number overall
    var draftPickNumber: Int?

    // MARK: - TMDB Metadata

    var popularity: Double
    var voteAverage: Double
    var voteCount: Int

    // MARK: - Computed Properties

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    var posterURLHighRes: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/original\(path)")
    }

    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(path)")
    }

    var trailerURL: URL? {
        guard let key = trailerKey else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }

    var year: Int? {
        guard let date = releaseDate else { return nil }
        return Calendar.current.component(.year, from: date)
    }

    var formattedReleaseDate: String {
        guard let date = releaseDate else { return "TBA" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var formattedRuntime: String? {
        guard let minutes = runtime else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    var formattedBudget: String? {
        guard let budget = budget, budget > 0 else { return nil }
        return formatCurrency(budget)
    }

    var isDrafted: Bool {
        draftedByTeamId != nil
    }

    var isReleased: Bool {
        guard let date = releaseDate else { return false }
        return date <= Date()
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        tmdbId: Int,
        title: String,
        originalTitle: String? = nil,
        tagline: String? = nil,
        overview: String = "",
        posterPath: String? = nil,
        backdropPath: String? = nil,
        trailerKey: String? = nil,
        releaseDate: Date? = nil,
        status: MovieStatus = .planned,
        runtime: Int? = nil,
        genres: [Genre] = [],
        genreIds: [Int] = [],
        certification: String? = nil,
        originalLanguage: String = "en",
        productionCompanies: [ProductionCompany] = [],
        budget: Int? = nil,
        cast: [CastMember] = [],
        crew: [CrewMember] = [],
        boxOffice: BoxOfficeData? = nil,
        ratings: RatingData? = nil,
        hasOfficialNumbers: Bool = false,
        isDraftable: Bool = true,
        draftedByTeamId: String? = nil,
        draftRound: Int? = nil,
        draftPickNumber: Int? = nil,
        popularity: Double = 0,
        voteAverage: Double = 0,
        voteCount: Int = 0
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.title = title
        self.originalTitle = originalTitle
        self.tagline = tagline
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.trailerKey = trailerKey
        self.releaseDate = releaseDate
        self.status = status
        self.runtime = runtime
        self.genres = genres
        self.genreIds = genreIds
        self.certification = certification
        self.originalLanguage = originalLanguage
        self.productionCompanies = productionCompanies
        self.budget = budget
        self.cast = cast
        self.crew = crew
        self.boxOffice = boxOffice
        self.ratings = ratings
        self.hasOfficialNumbers = hasOfficialNumbers
        self.isDraftable = isDraftable
        self.draftedByTeamId = draftedByTeamId
        self.draftRound = draftRound
        self.draftPickNumber = draftPickNumber
        self.popularity = popularity
        self.voteAverage = voteAverage
        self.voteCount = voteCount
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Supporting Types

enum MovieStatus: String, Codable {
    case rumored = "Rumored"
    case planned = "Planned"
    case inProduction = "In Production"
    case postProduction = "Post Production"
    case released = "Released"
    case canceled = "Canceled"
}

struct Genre: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct ProductionCompany: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String?

    var logoURL: URL? {
        guard let path = logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(path)")
    }
}

struct CastMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
    let order: Int

    var profileURL: URL? {
        guard let path = profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
    }
}

struct CrewMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let job: String
    let department: String
    let profilePath: String?

    var profileURL: URL? {
        guard let path = profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
    }
}

// MARK: - Box Office Data

struct BoxOfficeData: Codable, Hashable {
    var domestic: Int?
    var international: Int?
    var worldwide: Int?

    /// Opening weekend domestic
    var openingWeekend: Int?

    /// Last updated timestamp
    var lastUpdated: Date?

    var formattedDomestic: String? {
        guard let amount = domestic else { return nil }
        return formatLargeNumber(amount)
    }

    var formattedWorldwide: String? {
        guard let amount = worldwide else { return nil }
        return formatLargeNumber(amount)
    }

    var formattedOpeningWeekend: String? {
        guard let amount = openingWeekend else { return nil }
        return formatLargeNumber(amount)
    }

    private func formatLargeNumber(_ amount: Int) -> String {
        if amount >= 1_000_000_000 {
            return String(format: "$%.2fB", Double(amount) / 1_000_000_000)
        } else if amount >= 1_000_000 {
            return String(format: "$%.1fM", Double(amount) / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "$%.0fK", Double(amount) / 1_000)
        }
        return "$\(amount)"
    }
}

// MARK: - Rating Data

struct RatingData: Codable, Hashable {
    /// Rotten Tomatoes critic score (0-100)
    var rtCriticScore: Int?

    /// Rotten Tomatoes audience score (0-100)
    var rtAudienceScore: Int?

    /// IMDb rating (0-10)
    var imdbRating: Double?

    /// Metacritic score (0-100)
    var metacriticScore: Int?

    /// Last updated timestamp
    var lastUpdated: Date?

    /// Combined RT score (average of critic and audience)
    var combinedRTScore: Double? {
        guard let critic = rtCriticScore, let audience = rtAudienceScore else { return nil }
        return Double(critic + audience) / 2.0
    }

    var formattedRTCritic: String? {
        guard let score = rtCriticScore else { return nil }
        return "\(score)%"
    }

    var formattedRTAudience: String? {
        guard let score = rtAudienceScore else { return nil }
        return "\(score)%"
    }

    var formattedIMDb: String? {
        guard let rating = imdbRating else { return nil }
        return String(format: "%.1f", rating)
    }

    /// Determine if the movie is "Fresh" on RT
    var isFresh: Bool {
        guard let score = rtCriticScore else { return false }
        return score >= 60
    }

    /// Determine if the movie is "Certified Fresh" on RT
    var isCertifiedFresh: Bool {
        guard let score = rtCriticScore else { return false }
        return score >= 75
    }
}

// MARK: - Sample Data

extension FFMovie {
    static let sample = FFMovie(
        id: "movie_001",
        tmdbId: 12345,
        title: "Avatar 4",
        tagline: "Return to Pandora",
        overview: "The epic saga continues as Jake Sully and Neytiri face new challenges in an unexplored region of Pandora.",
        posterPath: "/sample_poster.jpg",
        backdropPath: "/sample_backdrop.jpg",
        releaseDate: Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 18)),
        status: .planned,
        runtime: 190,
        genres: [Genre(id: 878, name: "Science Fiction"), Genre(id: 12, name: "Adventure")],
        genreIds: [878, 12],
        certification: "PG-13",
        budget: 400_000_000,
        cast: [
            CastMember(id: 1, name: "Sam Worthington", character: "Jake Sully", profilePath: nil, order: 0),
            CastMember(id: 2, name: "Zoe Saldana", character: "Neytiri", profilePath: nil, order: 1)
        ],
        crew: [
            CrewMember(id: 3, name: "James Cameron", job: "Director", department: "Directing", profilePath: nil)
        ],
        boxOffice: BoxOfficeData(domestic: nil, international: nil, worldwide: nil),
        popularity: 156.7,
        voteAverage: 0,
        voteCount: 0
    )

    static let sampleMovies: [FFMovie] = [
        .sample,
        FFMovie(
            id: "movie_002",
            tmdbId: 12346,
            title: "Mission: Impossible 9",
            overview: "Ethan Hunt faces his most dangerous mission yet.",
            releaseDate: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 4)),
            status: .postProduction,
            genres: [Genre(id: 28, name: "Action"), Genre(id: 53, name: "Thriller")],
            genreIds: [28, 53],
            budget: 300_000_000,
            popularity: 145.2
        ),
        FFMovie(
            id: "movie_003",
            tmdbId: 12347,
            title: "Jurassic World 4",
            overview: "Dinosaurs are back, and this time they're everywhere.",
            releaseDate: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15)),
            status: .inProduction,
            genres: [Genre(id: 878, name: "Science Fiction"), Genre(id: 12, name: "Adventure")],
            genreIds: [878, 12],
            budget: 250_000_000,
            popularity: 132.8
        ),
        FFMovie(
            id: "movie_004",
            tmdbId: 12348,
            title: "Frozen 3",
            overview: "Elsa and Anna embark on a new magical adventure.",
            releaseDate: Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 25)),
            status: .inProduction,
            genres: [Genre(id: 16, name: "Animation"), Genre(id: 10751, name: "Family")],
            genreIds: [16, 10751],
            budget: 180_000_000,
            popularity: 128.5
        )
    ]
}
