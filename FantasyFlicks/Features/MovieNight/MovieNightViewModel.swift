//
//  MovieNightViewModel.swift
//  FantasyFlicks
//
//  Business logic for Movie Night swipe-to-match sessions
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class MovieNightViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var session: MovieNightSession?
    @Published var deckMovies: [FFMovie] = []
    @Published var allSwipes: [MovieNightSwipe] = []
    @Published var currentCardIndex: Int = 0
    @Published var results: [MovieNightResult] = []
    @Published var participantProgress: [String: Int] = [:]  // userId -> swipes count
    @Published var seenMovieIds: Set<Int> = []  // local toggle state for current user
    @Published var movieProviders: [Int: [WatchProvider]] = [:]  // tmdbId -> providers

    @Published var isLoading = false
    @Published var error: String?
    @Published var showCelebration = false
    @Published var celebrationMovie: FFMovie?

    // MARK: - Navigation State

    @Published var currentPhase: MovieNightPhase = .entry
    @Published var userSessions: [MovieNightSession] = []

    // MARK: - Computed Properties

    var isHost: Bool {
        guard let session, let userId = authService.currentUser?.id else { return false }
        return session.hostId == userId
    }

    var hasFinishedSwiping: Bool {
        currentCardIndex >= deckMovies.count && !deckMovies.isEmpty
    }

    var allParticipantsFinished: Bool {
        guard let session, !deckMovies.isEmpty else { return false }
        let deckSize = deckMovies.count
        return session.participantIds.allSatisfy { userId in
            (participantProgress[userId] ?? 0) >= deckSize
        }
    }

    var swipeProgressFraction: Double {
        guard !deckMovies.isEmpty else { return 0 }
        return Double(currentCardIndex) / Double(deckMovies.count)
    }

    // MARK: - Private Properties

    private let movieNightService = MovieNightService.shared
    private let tmdbService = TMDBService.shared
    private let authService = AuthenticationService.shared
    private var sessionListener: ListenerRegistration?
    private var swipesListener: ListenerRegistration?
    private var isDeckLoading = false  // prevent concurrent loadDeckMovies calls

    // MARK: - Initialization

    init() {
        // Load globally tracked seen movies into the session context
        seenMovieIds = SeenMoviesService.shared.seenTmdbIds
    }

    deinit {
        sessionListener?.remove()
        swipesListener?.remove()
    }

    // MARK: - Session Management

    /// Load user's existing sessions
    func loadUserSessions() async {
        do {
            userSessions = try await movieNightService.getUserSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Delete a session
    func deleteSession(_ session: MovieNightSession) async {
        do {
            try await movieNightService.deleteSession(sessionId: session.id)
            userSessions.removeAll { $0.id == session.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Update session filters (host only, before swiping starts)
    func updateSessionFilters(_ filters: MovieNightFilters) async {
        guard let session, isHost else { return }
        do {
            try await movieNightService.updateFilters(sessionId: session.id, filters: filters)
            // Listener will pick up the change and update self.session
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Create a new Movie Night session
    func createSession(filters: MovieNightFilters) async {
        isLoading = true
        error = nil

        do {
            let newSession = try await movieNightService.createSession(filters: filters)
            session = newSession
            setupListeners(sessionId: newSession.id)
            currentPhase = .lobby

            // Schedule a "still waiting" reminder in 30 minutes.
            // Cancelled when the host starts swiping or the session finishes.
            await NotificationManager.shared.schedule(
                id: "movie-night-waiting-\(newSession.id)",
                title: "Your Movie Night is waiting 🍿",
                body: "Jump back in to start swiping with friends.",
                afterMinutes: 30,
                userInfo: ["tab": Tab.movieNights.rawValue, "sessionId": newSession.id]
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Join a session by invite code
    func joinSession(inviteCode: String) async {
        isLoading = true
        error = nil

        do {
            let joinedSession = try await movieNightService.joinSession(inviteCode: inviteCode)
            session = joinedSession
            setupListeners(sessionId: joinedSession.id)
            currentPhase = .lobby
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Resume an existing session
    func resumeSession(_ existingSession: MovieNightSession) {
        session = existingSession
        setupListeners(sessionId: existingSession.id)

        // Refresh uploaded seen IDs if we're in the lobby (they may have changed)
        if existingSession.status == .lobby {
            let seenArray = Array(seenMovieIds)
            Task {
                try? await movieNightService.uploadSeenIds(sessionId: existingSession.id, seenIds: seenArray)
            }
        }

        switch existingSession.status {
        case .lobby:
            currentPhase = .lobby
        case .swiping:
            currentPhase = .swiping
            Task { await loadDeckMovies() }
        case .results:
            currentPhase = .results
            Task { await loadDeckMovies() }
        case .expired:
            break
        }
    }

    /// Host starts the swiping phase
    func startSwiping() async {
        guard let session else {
            self.error = "No active session found."
            return
        }
        guard isHost else {
            self.error = "Only the host can start swiping."
            return
        }

        isLoading = true
        error = nil

        do {
            // Snapshot filters before any async work so listener can't change them
            let filters = session.filters
            // Always read the live seen set from the service — the ViewModel's
            // local copy can be stale after a Letterboxd import or settings change.
            let liveSeenIds = SeenMoviesService.shared.seenTmdbIds
            let excludeIds: Set<Int>
            switch filters.excludeSeenMode {
            case .none:
                excludeIds = []
            case .mineOnly:
                excludeIds = liveSeenIds
            case .everyoneInParty:
                // Union of ALL participants' seen lists (uploaded on join)
                excludeIds = session.allParticipantsSeenIds.union(liveSeenIds)
            }

            let movies = try await tmdbService.buildMovieNightDeck(filters: filters, excludeTmdbIds: excludeIds)

            guard !movies.isEmpty else {
                let genreCount = filters.genreIds.count
                let providerCount = filters.watchProviderIds.count
                var hint = "No movies found matching your filters."
                if genreCount > 0 && providerCount > 0 {
                    hint += " Try selecting fewer genres or more streaming services."
                } else if genreCount > 0 {
                    hint += " Try selecting fewer genres."
                } else if providerCount > 0 {
                    hint += " Try adding more streaming services."
                } else {
                    hint += " Try lowering the minimum rating."
                }
                self.error = hint
                isLoading = false
                return
            }

            // Set deck BEFORE writing to Firestore so listener doesn't trigger loadDeckMovies
            deckMovies = movies
            let tmdbIds = movies.map { $0.tmdbId }

            // Write deck to Firestore and transition status
            try await movieNightService.startSession(sessionId: session.id, deckTmdbIds: tmdbIds)

            // Swiping started — cancel the "waiting" reminder
            NotificationManager.shared.cancel(id: "movie-night-waiting-\(session.id)")

            // Fetch providers for the deck
            await fetchProviders(for: movies)

            currentPhase = .swiping
        } catch {
            self.error = "Failed to build deck: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Swiping

    /// Process a swipe action
    func swipe(direction: SwipeDirection) async {
        guard let session, currentCardIndex < deckMovies.count else { return }

        let movie = deckMovies[currentCardIndex]
        let wantToWatch = direction == .right
        let hasSeenIt = seenMovieIds.contains(movie.tmdbId)

        // Advance card immediately for responsive UI
        currentCardIndex += 1

        do {
            try await movieNightService.submitSwipe(
                sessionId: session.id,
                tmdbId: movie.tmdbId,
                wantToWatch: wantToWatch,
                hasSeenIt: hasSeenIt
            )
        } catch {
            // Revert on failure
            currentCardIndex -= 1
            self.error = error.localizedDescription
        }

        // Check if we're done
        if hasFinishedSwiping && allParticipantsFinished {
            await finishSession()
        }
    }

    /// Undo the last swipe
    func undoLastSwipe() async {
        guard let session, currentCardIndex > 0 else { return }

        let previousIndex = currentCardIndex - 1
        let movie = deckMovies[previousIndex]

        currentCardIndex = previousIndex

        do {
            try await movieNightService.deleteSwipe(sessionId: session.id, tmdbId: movie.tmdbId)
        } catch {
            currentCardIndex += 1
            self.error = error.localizedDescription
        }
    }

    /// Toggle "seen it" for the current card
    func toggleSeenIt(tmdbId: Int) {
        if seenMovieIds.contains(tmdbId) {
            seenMovieIds.remove(tmdbId)
        } else {
            seenMovieIds.insert(tmdbId)
        }
    }

    /// Programmatic swipe (from buttons)
    func swipeRight() async {
        await swipe(direction: .right)
    }

    func swipeLeft() async {
        await swipe(direction: .left)
    }

    // MARK: - Results

    /// Compute results from all swipes
    func computeResults() {
        guard let session else { return }

        let participantCount = session.participantIds.count
        var resultsList: [MovieNightResult] = []

        for movie in deckMovies {
            let movieSwipes = allSwipes.filter { $0.tmdbId == movie.tmdbId }
            let rightSwipes = movieSwipes.filter { $0.wantToWatch }
            let seenByUsers = movieSwipes.filter { $0.hasSeenIt }.map { $0.userId }

            let matchScore = participantCount > 0
                ? Double(rightSwipes.count) / Double(participantCount)
                : 0

            let result = MovieNightResult(
                id: movie.tmdbId,
                movie: movie,
                matchScore: matchScore,
                swipedRightBy: rightSwipes.map { $0.userId },
                seenBy: seenByUsers,
                isUnanimous: rightSwipes.count == participantCount && participantCount >= 1,
                streamingProviders: movieProviders[movie.tmdbId] ?? []
            )

            resultsList.append(result)
        }

        // Sort by match score descending, then by vote average
        results = resultsList.sorted {
            if $0.matchScore != $1.matchScore {
                return $0.matchScore > $1.matchScore
            }
            return $0.movie.voteAverage > $1.movie.voteAverage
        }

        // Trigger celebration for top unanimous match
        if let topResult = results.first, topResult.isUnanimous {
            celebrationMovie = topResult.movie
            showCelebration = true
        }
    }

    /// Start a new round with the same group
    func playAgain() async {
        guard let session else { return }
        let filters = session.filters

        // Reset local state but keep global seen movies
        self.session = nil
        deckMovies = []
        allSwipes = []
        currentCardIndex = 0
        results = []
        participantProgress = [:]
        showCelebration = false
        celebrationMovie = nil

        // Reload global seen movies (don't clear them)
        seenMovieIds = SeenMoviesService.shared.seenTmdbIds

        // Clean up old listeners
        sessionListener?.remove()
        swipesListener?.remove()

        await createSession(filters: filters)
    }

    // MARK: - Private Methods

    private func setupListeners(sessionId: String) {
        sessionListener?.remove()
        swipesListener?.remove()

        // Session listener
        sessionListener = movieNightService.listenToSession(sessionId: sessionId) { [weak self] updatedSession in
            guard let self else { return }
            self.session = updatedSession

            // React to status changes
            if let status = updatedSession?.status {
                switch status {
                case .swiping:
                    if self.currentPhase != .swiping {
                        self.currentPhase = .swiping
                    }
                    // Load deck if not already loaded (host loads in startSwiping)
                    if self.deckMovies.isEmpty && !self.isDeckLoading {
                        Task { await self.loadDeckMovies() }
                    }
                case .results:
                    let wasTransitioning = self.currentPhase != .results
                    if wasTransitioning {
                        self.currentPhase = .results
                        // Only compute if deck is loaded
                        if !self.deckMovies.isEmpty {
                            self.computeResults()
                        }
                        // Fire a local notification only if the app is in the background
                        // (otherwise user is already seeing the results screen).
                        if UIApplication.shared.applicationState != .active,
                           let sessionId = updatedSession?.id {
                            Task {
                                await NotificationManager.shared.schedule(
                                    id: "movie-night-results-\(sessionId)",
                                    title: "Movie Night results are in! 🏆",
                                    body: "Come see what your group picked.",
                                    afterMinutes: 0,
                                    userInfo: ["tab": Tab.movieNights.rawValue, "sessionId": sessionId]
                                )
                            }
                        }
                        // Clean up the waiting reminder if it's still scheduled
                        if let sessionId = updatedSession?.id {
                            NotificationManager.shared.cancel(id: "movie-night-waiting-\(sessionId)")
                        }
                    }
                default:
                    break
                }
            }
        }

        // Swipes listener
        swipesListener = movieNightService.listenToSwipes(sessionId: sessionId) { [weak self] swipes in
            guard let self else { return }
            self.allSwipes = swipes

            // Update participant progress
            var progress: [String: Int] = [:]
            for swipe in swipes {
                progress[swipe.userId, default: 0] += 1
            }
            self.participantProgress = progress

            // Check if all done
            if self.hasFinishedSwiping && self.allParticipantsFinished {
                Task { await self.finishSession() }
            }
        }
    }

    private func loadDeckMovies() async {
        guard let session, !session.deckTmdbIds.isEmpty else { return }
        guard !isDeckLoading else { return }  // prevent concurrent calls
        isDeckLoading = true
        isLoading = true

        // Fetch deck movies in small batches to avoid TMDB rate limits.
        //
        // Every participant must end up with a deck of exactly the same length:
        // "everyone has finished" compares each person's swipe count against
        // the local deck size, so one client silently dropping a movie that
        // failed to load would strand the whole party on the waiting screen.
        // A movie that can't be fetched is retried once and then filled in from
        // whatever metadata we already have locally.
        var fetched: [Int: FFMovie] = [:]
        let tmdbIds = session.deckTmdbIds
        let batchSize = 5

        for batchStart in stride(from: 0, to: tmdbIds.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, tmdbIds.count)
            let batch = Array(tmdbIds[batchStart..<batchEnd])

            await withTaskGroup(of: (Int, FFMovie?).self) { group in
                for tmdbId in batch {
                    group.addTask { [weak self] in
                        guard let self else { return (tmdbId, nil) }
                        if let movie = try? await self.tmdbService.getFullMovie(id: tmdbId) {
                            return (tmdbId, movie)
                        }
                        // One retry — most failures here are transient rate limits.
                        return (tmdbId, try? await self.tmdbService.getFullMovie(id: tmdbId))
                    }
                }

                for await (tmdbId, movie) in group {
                    if let movie { fetched[tmdbId] = movie }
                }
            }
        }

        // Rebuild in deck order, substituting a local placeholder for anything
        // TMDB wouldn't give us so the deck length always matches the session.
        deckMovies = tmdbIds.map { tmdbId in
            fetched[tmdbId]
                ?? SeenMoviesService.shared.cachedMovie(for: tmdbId)?.toFFMovie()
                ?? FFMovie(tmdbId: tmdbId, title: "Unavailable", overview: "")
        }
        await fetchProviders(for: deckMovies)

        // Restore current card index from existing swipes
        if let userId = authService.currentUser?.id {
            let mySwipeCount = allSwipes.filter { $0.userId == userId }.count
            currentCardIndex = mySwipeCount
        }

        // If we're on the results phase, compute now that deck is loaded
        if currentPhase == .results {
            computeResults()
        }

        isLoading = false
        isDeckLoading = false
    }

    private func fetchProviders(for movies: [FFMovie]) async {
        // Batch fetch watch providers in small groups to avoid rate limits
        let batchSize = 5
        for batchStart in stride(from: 0, to: movies.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, movies.count)
            let batch = Array(movies[batchStart..<batchEnd])

            await withTaskGroup(of: (Int, [WatchProvider]).self) { group in
                for movie in batch {
                    group.addTask { [weak self] in
                        guard let self else { return (movie.tmdbId, []) }
                        do {
                            let response = try await self.tmdbService.getWatchProviders(movieId: movie.tmdbId)
                            if let usProviders = response.results["US"]?.flatrate {
                                return (movie.tmdbId, usProviders.map {
                                    WatchProvider(id: $0.providerId, name: $0.providerName, logoPath: $0.logoPath)
                                })
                            }
                        } catch {}
                        return (movie.tmdbId, [])
                    }
                }

                for await (tmdbId, providers) in group {
                    movieProviders[tmdbId] = providers
                }
            }
        }
    }

    private func finishSession() async {
        guard let session, session.status == .swiping else { return }

        do {
            try await movieNightService.completeSession(sessionId: session.id)
            computeResults()
            currentPhase = .results
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Host-initiated "Show Results Now" — bypasses the participant-progress
    /// check so a stuck session can always move forward. Also computes results
    /// locally and transitions phase even if the Firestore write fails, so the
    /// current user never gets stranded on the waiting screen.
    func finishNow() async {
        guard let session, isHost else { return }
        try? await movieNightService.completeSession(sessionId: session.id)
        computeResults()
        currentPhase = .results
    }
}

// MARK: - Phase

enum MovieNightPhase {
    case entry
    case setup
    case lobby
    case swiping
    case results
}
