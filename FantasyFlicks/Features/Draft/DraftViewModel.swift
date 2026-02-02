//
//  DraftViewModel.swift
//  FantasyFlicks
//
//  Manages draft data with real-time Firestore sync
//

import Foundation
import SwiftUI
import FirebaseFirestore
import Combine

// MARK: - Sort Order

enum MovieSortOrder: String, CaseIterable {
    case popularity = "Most Popular"
    case releaseDate = "Release Date"
    case title = "Title A-Z"
    case titleDesc = "Title Z-A"

    var icon: String {
        switch self {
        case .popularity: return "flame.fill"
        case .releaseDate: return "calendar"
        case .title: return "textformat"
        case .titleDesc: return "textformat"
        }
    }
}

@MainActor
final class DraftViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var upcomingDrafts: [DraftInfo] = []
    @Published private(set) var activeDrafts: [DraftInfo] = []
    @Published private(set) var completedDrafts: [DraftInfo] = []
    @Published private(set) var currentDraft: FFDraft?
    @Published private(set) var allFetchedMovies: [FFMovie] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isSubmittingPick = false
    @Published private(set) var remainingTime: Int = 0
    @Published private(set) var currentPage: Int = 1
    @Published private(set) var hasMoreMovies: Bool = true
    @Published var sortOrder: MovieSortOrder = .popularity
    @Published var error: String?

    // Computed property for available movies (filters out picked movies)
    var availableMovies: [FFMovie] {
        let pickedIds = Set(currentDraft?.picks.map { $0.movieId } ?? [])
        let filtered = allFetchedMovies.filter { !pickedIds.contains(String($0.id)) }

        switch sortOrder {
        case .popularity:
            return filtered.sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
        case .releaseDate:
            return filtered.sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
        case .title:
            return filtered.sorted { $0.title < $1.title }
        case .titleDesc:
            return filtered.sorted { $0.title > $1.title }
        }
    }

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private let authService = AuthenticationService.shared
    private var draftsListener: ListenerRegistration?
    private var currentDraftListener: ListenerRegistration?
    private var picksListener: ListenerRegistration?
    private var timerCancellable: AnyCancellable?
    private var currentYear: Int = Calendar.current.component(.year, from: Date())

    // MARK: - Types

    struct DraftInfo: Identifiable {
        let id: String
        let leagueName: String
        let draftStatus: DraftStatus
        let scheduledAt: Date?
        let currentRound: Int
        let currentPickInRound: Int
        let isYourTurn: Bool
        let memberCount: Int
        let maxMembers: Int
        let completedAt: Date?
        let moviesPerPlayer: Int
    }

    // MARK: - Initialization

    init() {
        setupDraftsListener()
    }

    deinit {
        draftsListener?.remove()
        currentDraftListener?.remove()
        picksListener?.remove()
        timerCancellable?.cancel()
    }

    // MARK: - Real-time Listener

    private func setupDraftsListener() {
        guard let userId = authService.currentUser?.id else { return }

        draftsListener?.remove()

        // Listen to user's leagues for draft info
        draftsListener = db.collection("leagues")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        self.error = error.localizedDescription
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    var upcoming: [DraftInfo] = []
                    var active: [DraftInfo] = []
                    var completed: [DraftInfo] = []

                    for doc in documents {
                        if let draftInfo = self.parseDraftInfo(from: doc, userId: userId) {
                            switch draftInfo.draftStatus {
                            case .pending, .scheduled:
                                upcoming.append(draftInfo)
                            case .inProgress, .paused:
                                active.append(draftInfo)
                            case .completed:
                                completed.append(draftInfo)
                            }
                        }
                    }

                    self.upcomingDrafts = upcoming.sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
                    self.activeDrafts = active
                    self.completedDrafts = completed.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                }
            }
    }

    // MARK: - Public Methods

    func loadDraft(draftId: String) async {
        isLoading = true
        defer { isLoading = false }

        currentDraftListener?.remove()

        currentDraftListener = db.collection("drafts").document(draftId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        self.error = error.localizedDescription
                        return
                    }

                    guard let data = snapshot?.data() else { return }
                    self.currentDraft = self.parseDraft(from: data, id: draftId)

                    // Start timer if it's an active draft
                    if let draft = self.currentDraft, draft.isActive {
                        self.startPickTimer()
                    }
                }
            }
    }

    func submitPick(movieId: String, movieTitle: String, posterPath: String?) async -> Bool {
        guard let userId = authService.currentUser?.id,
              let draft = currentDraft,
              draft.currentPickerId == userId else {
            error = "It's not your turn to pick"
            return false
        }

        isSubmittingPick = true
        defer { isSubmittingPick = false }

        let pickId = UUID().uuidString
        let secondsTaken = draft.pickTimerSeconds - remainingTime

        let pickData: [String: Any] = [
            "draftId": draft.id,
            "teamId": userId, // For simplicity, using userId as teamId
            "userId": userId,
            "movieId": movieId,
            "movieTitle": movieTitle,
            "moviePosterPath": posterPath as Any,
            "overallPickNumber": draft.currentOverallPick,
            "roundNumber": draft.currentRound,
            "pickInRound": draft.currentPickInRound,
            "pickedAt": FieldValue.serverTimestamp(),
            "secondsTaken": secondsTaken,
            "wasAutoPick": false
        ]

        do {
            // Add the pick
            try await db.collection("drafts").document(draft.id)
                .collection("picks").document(pickId).setData(pickData)

            // Update draft state
            let nextState = calculateNextDraftState(draft: draft)
            try await db.collection("drafts").document(draft.id).updateData(nextState)

            // Update user's total movies drafted
            try await db.collection("users").document(userId).updateData([
                "totalMoviesDrafted": FieldValue.increment(Int64(1))
            ])

            return true
        } catch {
            self.error = "Failed to submit pick: \(error.localizedDescription)"
            return false
        }
    }

    func startDraft(leagueId: String) async -> String? {
        guard authService.currentUser?.id != nil else { return nil }

        do {
            // Get league data
            let leagueDoc = try await db.collection("leagues").document(leagueId).getDocument()
            guard let leagueData = leagueDoc.data() else { return nil }

            let memberIds = leagueData["memberIds"] as? [String] ?? []
            let settingsData = leagueData["settings"] as? [String: Any] ?? [:]
            let draftType = DraftType(rawValue: settingsData["draftType"] as? String ?? "") ?? .serpentine
            let moviesPerPlayer = settingsData["moviesPerPlayer"] as? Int ?? 5
            let pickTimerSeconds = settingsData["pickTimerSeconds"] as? Int ?? 120

            // Randomize draft order
            let draftOrder = memberIds.shuffled()

            let draftId = UUID().uuidString
            let draftData: [String: Any] = [
                "leagueId": leagueId,
                "draftType": draftType.rawValue,
                "draftOrder": draftOrder,
                "totalRounds": moviesPerPlayer,
                "pickTimerSeconds": pickTimerSeconds,
                "status": DraftStatus.inProgress.rawValue,
                "currentRound": 1,
                "currentPickInRound": 1,
                "currentOverallPick": 1,
                "currentPickerId": draftOrder.first as Any,
                "pickTimerStartedAt": FieldValue.serverTimestamp(),
                "createdAt": FieldValue.serverTimestamp(),
                "startedAt": FieldValue.serverTimestamp()
            ]

            try await db.collection("drafts").document(draftId).setData(draftData)

            // Update league with draft info
            try await db.collection("leagues").document(leagueId).updateData([
                "draftId": draftId,
                "draftStatus": DraftStatus.inProgress.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])

            return draftId
        } catch {
            self.error = "Failed to start draft: \(error.localizedDescription)"
            return nil
        }
    }

    func loadAvailableMovies(forYear year: Int) async {
        isLoading = true
        currentYear = year
        currentPage = 1
        hasMoreMovies = true
        allFetchedMovies = []

        defer { isLoading = false }

        // Fetch movies from TMDB service (sorted by popularity by default)
        do {
            let response = try await TMDBService.shared.discoverMovies(year: year, page: 1)
            let movies = response.results.map { TMDBService.shared.convertToFFMovie($0) }
            allFetchedMovies = movies
            hasMoreMovies = response.page < response.totalPages
        } catch {
            self.error = "Failed to load movies: \(error.localizedDescription)"
        }
    }

    func loadMoreMovies() async {
        guard !isLoadingMore && hasMoreMovies else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1

        do {
            let response = try await TMDBService.shared.discoverMovies(year: currentYear, page: nextPage)
            let newMovies = response.results.map { TMDBService.shared.convertToFFMovie($0) }

            // Append new movies, avoiding duplicates
            let existingIds = Set(allFetchedMovies.map { $0.id })
            let uniqueNewMovies = newMovies.filter { !existingIds.contains($0.id) }
            allFetchedMovies.append(contentsOf: uniqueNewMovies)

            currentPage = nextPage
            hasMoreMovies = response.page < response.totalPages
        } catch {
            self.error = "Failed to load more movies: \(error.localizedDescription)"
        }
    }

    func refreshMoviesAfterPick() {
        // Trigger UI update by touching the draft (picks array changed)
        objectWillChange.send()
    }

    // MARK: - Timer

    private func startPickTimer() {
        timerCancellable?.cancel()

        guard let draft = currentDraft,
              draft.pickTimerSeconds > 0,
              let startTime = draft.pickTimerStartedAt else {
            remainingTime = 0
            return
        }

        let elapsed = Int(Date().timeIntervalSince(startTime))
        remainingTime = max(0, draft.pickTimerSeconds - elapsed)

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingTime > 0 {
                    self.remainingTime -= 1
                } else {
                    self.timerCancellable?.cancel()
                    // Auto-pick logic would go here
                }
            }
    }

    // MARK: - Helper Methods

    private func parseDraftInfo(from document: DocumentSnapshot, userId: String) -> DraftInfo? {
        guard let data = document.data() else { return nil }

        let draftStatus = DraftStatus(rawValue: data["draftStatus"] as? String ?? "") ?? .pending

        var scheduledAt: Date?
        if let timestamp = data["draftScheduledAt"] as? Timestamp {
            scheduledAt = timestamp.dateValue()
        }

        var completedAt: Date?
        if let timestamp = data["draftCompletedAt"] as? Timestamp {
            completedAt = timestamp.dateValue()
        }

        let settingsData = data["settings"] as? [String: Any] ?? [:]
        let moviesPerPlayer = settingsData["moviesPerPlayer"] as? Int ?? 5

        // For active drafts, check if it's this user's turn
        let currentPickerId = data["currentPickerId"] as? String
        let isYourTurn = currentPickerId == userId && draftStatus == .inProgress

        return DraftInfo(
            id: document.documentID,
            leagueName: data["name"] as? String ?? "Unknown League",
            draftStatus: draftStatus,
            scheduledAt: scheduledAt,
            currentRound: data["currentRound"] as? Int ?? 1,
            currentPickInRound: data["currentPickInRound"] as? Int ?? 1,
            isYourTurn: isYourTurn,
            memberCount: (data["memberIds"] as? [String])?.count ?? 0,
            maxMembers: data["maxMembers"] as? Int ?? 8,
            completedAt: completedAt,
            moviesPerPlayer: moviesPerPlayer
        )
    }

    private func parseDraft(from data: [String: Any], id: String) -> FFDraft {
        let picks = (data["picks"] as? [[String: Any]] ?? []).map { pickData in
            FFDraftPick(
                id: pickData["id"] as? String ?? UUID().uuidString,
                draftId: id,
                teamId: pickData["teamId"] as? String ?? "",
                userId: pickData["userId"] as? String ?? "",
                movieId: pickData["movieId"] as? String ?? "",
                movieTitle: pickData["movieTitle"] as? String ?? "",
                moviePosterPath: pickData["moviePosterPath"] as? String,
                overallPickNumber: pickData["overallPickNumber"] as? Int ?? 0,
                roundNumber: pickData["roundNumber"] as? Int ?? 0,
                pickInRound: pickData["pickInRound"] as? Int ?? 0,
                pickedAt: (pickData["pickedAt"] as? Timestamp)?.dateValue() ?? Date(),
                secondsTaken: pickData["secondsTaken"] as? Int,
                wasAutoPick: pickData["wasAutoPick"] as? Bool ?? false
            )
        }

        var pickTimerStartedAt: Date?
        if let timestamp = data["pickTimerStartedAt"] as? Timestamp {
            pickTimerStartedAt = timestamp.dateValue()
        }

        var startedAt: Date?
        if let timestamp = data["startedAt"] as? Timestamp {
            startedAt = timestamp.dateValue()
        }

        return FFDraft(
            id: id,
            leagueId: data["leagueId"] as? String ?? "",
            draftType: DraftType(rawValue: data["draftType"] as? String ?? "") ?? .serpentine,
            draftOrder: data["draftOrder"] as? [String] ?? [],
            totalRounds: data["totalRounds"] as? Int ?? 5,
            pickTimerSeconds: data["pickTimerSeconds"] as? Int ?? 120,
            status: DraftStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
            currentRound: data["currentRound"] as? Int ?? 1,
            currentPickInRound: data["currentPickInRound"] as? Int ?? 1,
            currentOverallPick: data["currentOverallPick"] as? Int ?? 1,
            currentPickerId: data["currentPickerId"] as? String,
            pickTimerStartedAt: pickTimerStartedAt,
            picks: picks,
            startedAt: startedAt
        )
    }

    private func calculateNextDraftState(draft: FFDraft) -> [String: Any] {
        let totalPlayers = draft.draftOrder.count
        let nextOverallPick = draft.currentOverallPick + 1

        // Check if draft is complete
        if nextOverallPick > draft.totalPicks {
            return [
                "status": DraftStatus.completed.rawValue,
                "currentOverallPick": nextOverallPick,
                "completedAt": FieldValue.serverTimestamp()
            ]
        }

        let nextRound = ((nextOverallPick - 1) / totalPlayers) + 1
        let nextPickInRound = ((nextOverallPick - 1) % totalPlayers) + 1

        // Calculate next picker based on draft type
        let nextPickerIndex: Int
        if draft.draftType == .serpentine && nextRound % 2 == 0 {
            nextPickerIndex = totalPlayers - nextPickInRound
        } else {
            nextPickerIndex = nextPickInRound - 1
        }

        let nextPickerId = draft.draftOrder[nextPickerIndex]

        return [
            "currentRound": nextRound,
            "currentPickInRound": nextPickInRound,
            "currentOverallPick": nextOverallPick,
            "currentPickerId": nextPickerId,
            "pickTimerStartedAt": FieldValue.serverTimestamp()
        ]
    }
}
