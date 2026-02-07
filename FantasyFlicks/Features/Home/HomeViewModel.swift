//
//  HomeViewModel.swift
//  FantasyFlicks
//
//  ViewModel for the home screen - fetches upcoming movies and manages user data
//

import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var upcomingMovies: [FFMovie] = []
    @Published var nowPlayingMovies: [FFMovie] = []
    @Published var isLoadingUpcoming = false
    @Published var isLoadingNowPlaying = false
    @Published var error: String?

    // User leagues from Firestore
    @Published var userLeagues: [FFLeague] = []
    @Published var activeDraft: ActiveDraftInfo?

    // Real stats from user profile
    @Published var totalLeagues = 0
    @Published var totalMoviesDrafted = 0
    @Published var bestRank = 0
    @Published var leaguesWon = 0

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private let authService = AuthenticationService.shared
    private var leaguesListener: ListenerRegistration?

    // MARK: - Types

    struct ActiveDraftInfo {
        let leagueId: String
        let leagueName: String
        let draftId: String
        let isOscarMode: Bool
        let isYourTurn: Bool
        let currentRound: Int
        let currentPick: Int
    }

    // MARK: - Initialization

    init() {
        setupLeaguesListener()
    }

    deinit {
        leaguesListener?.remove()
    }

    // MARK: - Real-time Listener

    private func setupLeaguesListener() {
        guard let userId = authService.currentUser?.id else { return }

        leaguesListener = db.collection("leagues")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        print("Error fetching leagues: \(error)")
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    self.userLeagues = documents.compactMap { doc -> FFLeague? in
                        self.parseLeague(from: doc)
                    }

                    // Check for active drafts
                    if let activeDraftLeague = self.userLeagues.first(where: { $0.draftStatus == .inProgress }),
                       let draftId = activeDraftLeague.draftId {
                        self.activeDraft = ActiveDraftInfo(
                            leagueId: activeDraftLeague.id,
                            leagueName: activeDraftLeague.name,
                            draftId: draftId,
                            isOscarMode: activeDraftLeague.isOscarMode,
                            isYourTurn: false, // Would need draft data to determine
                            currentRound: 1,
                            currentPick: 1
                        )
                    } else {
                        self.activeDraft = nil
                    }
                }
            }
    }

    // MARK: - Public Methods

    /// Fetch all home screen data
    func fetchHomeData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchUpcomingMovies() }
            group.addTask { await self.fetchNowPlayingMovies() }
            group.addTask { await self.fetchUserStats() }
        }
    }

    /// Fetch user stats from Firebase
    func fetchUserStats() async {
        guard let user = authService.currentUser else {
            // Use default values
            totalLeagues = 0
            totalMoviesDrafted = 0
            bestRank = 0
            leaguesWon = 0
            return
        }

        // Get real stats from user
        totalLeagues = user.totalLeagues
        totalMoviesDrafted = user.totalMoviesDrafted
        leaguesWon = user.leaguesWon

        // Fetch best rank from actual league standings
        await fetchBestRank(userId: user.id)

        // Also try to fetch fresh data from Firestore
        do {
            let doc = try await db.collection("users").document(user.id).getDocument()
            if let data = doc.data() {
                totalLeagues = data["totalLeagues"] as? Int ?? totalLeagues
                totalMoviesDrafted = data["totalMoviesDrafted"] as? Int ?? totalMoviesDrafted
                leaguesWon = data["leaguesWon"] as? Int ?? leaguesWon
            }
        } catch {
            // Use cached values if fetch fails
        }
    }

    /// Fetch best rank from all leagues the user is in
    private func fetchBestRank(userId: String) async {
        do {
            // Get all leagues the user is a member of
            let leaguesSnapshot = try await db.collection("leagues")
                .whereField("memberIds", arrayContains: userId)
                .whereField("draftStatus", isEqualTo: DraftStatus.completed.rawValue)
                .getDocuments()

            var bestFoundRank = 0

            for leagueDoc in leaguesSnapshot.documents {
                guard let draftId = leagueDoc.data()["draftId"] as? String else { continue }

                // Get all picks for this draft
                let picksSnapshot = try await db.collection("drafts").document(draftId)
                    .collection("picks")
                    .getDocuments()

                // Group picks by user and calculate scores
                var userScores: [(userId: String, score: Double)] = []
                let picksByUser = Dictionary(grouping: picksSnapshot.documents, by: { $0.data()["userId"] as? String ?? "" })

                for (pickUserId, userPicks) in picksByUser {
                    let score = userPicks.compactMap { $0.data()["pointsEarned"] as? Double }.reduce(0, +)
                    userScores.append((userId: pickUserId, score: score))
                }

                // Sort by score
                userScores.sort { $0.score > $1.score }

                // Find this user's rank
                if let userIndex = userScores.firstIndex(where: { $0.userId == userId }) {
                    let rank = userIndex + 1
                    if bestFoundRank == 0 || rank < bestFoundRank {
                        bestFoundRank = rank
                    }
                }
            }

            bestRank = bestFoundRank

        } catch {
            // If fetch fails, keep existing value
        }
    }

    /// Fetch upcoming movies from TMDB
    func fetchUpcomingMovies() async {
        guard !isLoadingUpcoming else { return }

        isLoadingUpcoming = true
        error = nil

        do {
            // Use the blockbusters endpoint which filters by future dates
            let response = try await TMDBService.shared.getUpcomingBlockbusters(page: 1)

            let today = Date()
            // Filter to only include movies with release dates in the future
            upcomingMovies = response.results
                .map { TMDBService.shared.convertToFFMovie($0) }
                .filter { movie in
                    guard let releaseDate = movie.releaseDate else { return false }
                    return releaseDate > today
                }
                .prefix(10)
                .map { $0 }

        } catch let networkError as NetworkError {
            error = networkError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingUpcoming = false
    }

    /// Fetch now playing movies from TMDB
    func fetchNowPlayingMovies() async {
        guard !isLoadingNowPlaying else { return }

        isLoadingNowPlaying = true

        do {
            let response = try await TMDBService.shared.getNowPlayingMovies(page: 1)

            nowPlayingMovies = response.results.prefix(10).map { tmdbMovie in
                TMDBService.shared.convertToFFMovie(tmdbMovie)
            }

        } catch {
            // Silently fail for secondary content
        }

        isLoadingNowPlaying = false
    }

    /// Refresh all data
    func refresh() async {
        await fetchHomeData()
    }

    /// Check if any data is loading
    var isLoading: Bool {
        isLoadingUpcoming || isLoadingNowPlaying
    }

    // MARK: - Helper Methods

    private func parseLeague(from document: DocumentSnapshot) -> FFLeague? {
        guard let data = document.data() else { return nil }

        let settingsData = data["settings"] as? [String: Any] ?? [:]
        let settings = LeagueSettings(
            draftType: DraftType(rawValue: settingsData["draftType"] as? String ?? "") ?? .serpentine,
            moviesPerPlayer: settingsData["moviesPerPlayer"] as? Int ?? 5,
            scoringMode: ScoringMode(rawValue: settingsData["scoringMode"] as? String ?? "") ?? .boxOfficeWorldwide
        )

        return FFLeague(
            id: document.documentID,
            name: data["name"] as? String ?? "Unknown League",
            description: data["description"] as? String,
            settings: settings,
            commissionerId: data["commissionerId"] as? String ?? "",
            memberIds: data["memberIds"] as? [String] ?? [],
            maxMembers: data["maxMembers"] as? Int ?? 8,
            inviteCode: data["inviteCode"] as? String ?? "",
            draftStatus: DraftStatus(rawValue: data["draftStatus"] as? String ?? "") ?? .pending,
            seasonYear: data["seasonYear"] as? Int ?? Calendar.current.component(.year, from: Date())
        )
    }
}
