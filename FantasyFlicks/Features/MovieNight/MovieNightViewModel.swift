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
        // Use deckMovies.count (actually loaded) not deckTmdbIds.count (requested)
        // since some movies may fail to load from TMDB
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

    /// Create a new Movie Night session
    func createSession(filters: MovieNightFilters) async {
        isLoading = true
        error = nil

        do {
            let newSession = try await movieNightService.createSession(filters: filters)
            session = newSession
            setupListeners(sessionId: newSession.id)
            currentPhase = .lobby
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
        guard isHost, let session else { return }
        isLoading = true
        error = nil

        do {
            // Build the deck from TMDB, excluding movies participants have already seen
            let excludeIds: Set<Int> = session.filters.excludeSeenMovies ? seenMovieIds : []
            let movies = try await tmdbService.buildMovieNightDeck(filters: session.filters, excludeTmdbIds: excludeIds)
            guard !movies.isEmpty else {
                self.error = "No movies found matching your filters. Try broadening your selections."
                isLoading = false
                return
            }

            deckMovies = movies
            let tmdbIds = movies.map { $0.tmdbId }

            // Write deck to Firestore and transition status
            try await movieNightService.startSession(sessionId: session.id, deckTmdbIds: tmdbIds)

            // Fetch providers for the deck
            await fetchProviders(for: movies)

            currentPhase = .swiping
        } catch {
            self.error = error.localizedDescription
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

        // Reset local state
        self.session = nil
        deckMovies = []
        allSwipes = []
        currentCardIndex = 0
        results = []
        participantProgress = [:]
        seenMovieIds = []
        showCelebration = false
        celebrationMovie = nil

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
                        // Only load deck if not already loaded (host loads it in startSwiping)
                        if self.deckMovies.isEmpty {
                            Task { await self.loadDeckMovies() }
                        }
                    }
                case .results:
                    if self.currentPhase != .results {
                        self.currentPhase = .results
                        self.computeResults()
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
        isLoading = true

        // Fetch every deck movie by individual ID so we always get the full deck
        do {
            var orderedMovies: [FFMovie] = []

            // Batch fetch with concurrency limit
            await withTaskGroup(of: (Int, FFMovie?).self) { group in
                for (index, tmdbId) in session.deckTmdbIds.enumerated() {
                    group.addTask { [weak self] in
                        guard let self else { return (index, nil) }
                        return (index, try? await self.tmdbService.getFullMovie(id: tmdbId))
                    }
                }

                var indexed: [(Int, FFMovie)] = []
                for await (index, movie) in group {
                    if let movie { indexed.append((index, movie)) }
                }

                // Preserve the original deck order
                orderedMovies = indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
            }

            deckMovies = orderedMovies
            await fetchProviders(for: orderedMovies)

            // Restore current card index from existing swipes
            if let userId = authService.currentUser?.id {
                let mySwipeCount = allSwipes.filter { $0.userId == userId }.count
                currentCardIndex = mySwipeCount
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchProviders(for movies: [FFMovie]) async {
        // Batch fetch watch providers for movies (limit concurrency)
        await withTaskGroup(of: (Int, [WatchProvider]).self) { group in
            for movie in movies.prefix(25) {
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
}

// MARK: - Phase

enum MovieNightPhase {
    case entry
    case setup
    case lobby
    case swiping
    case results
}
