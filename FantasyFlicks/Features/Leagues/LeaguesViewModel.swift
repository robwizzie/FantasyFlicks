//
//  LeaguesViewModel.swift
//  FantasyFlicks
//
//  Manages leagues data with Firestore integration
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class LeaguesViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var leagues: [FFLeague] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isJoining = false
    @Published private(set) var isCreating = false
    @Published var error: String?
    @Published var successMessage: String?

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private var leaguesListener: ListenerRegistration?
    private let authService = AuthenticationService.shared

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

        leaguesListener?.remove()

        leaguesListener = db.collection("leagues")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    self?.leagues = documents.compactMap { doc in
                        self?.parseLeague(from: doc)
                    }.sorted { ($0.updatedAt) > ($1.updatedAt) }
                }
            }
    }

    // MARK: - Public Methods

    func refreshLeagues() async {
        guard let userId = authService.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("leagues")
                .whereField("memberIds", arrayContains: userId)
                .getDocuments()

            leagues = snapshot.documents.compactMap { parseLeague(from: $0) }
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createLeague(
        name: String,
        description: String?,
        maxMembers: Int,
        settings: LeagueSettings
    ) async -> FFLeague? {
        guard let userId = authService.currentUser?.id else {
            error = "You must be signed in to create a league"
            return nil
        }

        isCreating = true
        defer { isCreating = false }

        let leagueId = UUID().uuidString
        let inviteCode = FFLeague.generateInviteCode()

        let leagueData: [String: Any] = [
            "name": name,
            "description": description as Any,
            "commissionerId": userId,
            "memberIds": [userId],
            "maxMembers": maxMembers,
            "inviteCode": inviteCode,
            "isPublic": false,
            "draftStatus": DraftStatus.pending.rawValue,
            "seasonYear": Calendar.current.component(.year, from: Date()),
            "isSeasonComplete": false,
            "settings": [
                "draftType": settings.draftType.rawValue,
                "draftOrderType": settings.draftOrderType.rawValue,
                "scoringMode": settings.scoringMode.rawValue,
                "scoringDirection": settings.scoringDirection.rawValue,
                "moviesPerPlayer": settings.moviesPerPlayer,
                "pickTimerSeconds": settings.pickTimerSeconds,
                "allowTrading": settings.allowTrading,
                "tradeReviewPeriodDays": settings.tradeReviewPeriodDays,
                "includeOscarPredictions": settings.includeOscarPredictions,
                "oscarBonusMultiplier": settings.oscarBonusMultiplier,
                "movieFilters": [
                    "theatricalOnly": settings.movieFilters.theatricalOnly,
                    "minimumBudget": settings.movieFilters.minimumBudget as Any,
                    "excludedGenreIds": settings.movieFilters.excludedGenreIds
                ]
            ],
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await db.collection("leagues").document(leagueId).setData(leagueData)

            // Update user's league count
            try await db.collection("users").document(userId).updateData([
                "totalLeagues": FieldValue.increment(Int64(1))
            ])

            successMessage = "League created! Invite code: \(inviteCode)"

            return FFLeague(
                id: leagueId,
                name: name,
                description: description,
                settings: settings,
                commissionerId: userId,
                memberIds: [userId],
                maxMembers: maxMembers,
                inviteCode: inviteCode
            )
        } catch {
            self.error = "Failed to create league: \(error.localizedDescription)"
            return nil
        }
    }

    func joinLeague(inviteCode: String) async -> Bool {
        guard let userId = authService.currentUser?.id else {
            error = "You must be signed in to join a league"
            return false
        }

        isJoining = true
        defer { isJoining = false }

        let normalizedCode = inviteCode.uppercased().trimmingCharacters(in: .whitespaces)

        do {
            let snapshot = try await db.collection("leagues")
                .whereField("inviteCode", isEqualTo: normalizedCode)
                .limit(to: 1)
                .getDocuments()

            guard let document = snapshot.documents.first else {
                error = "Invalid invite code. Please check and try again."
                return false
            }

            guard let league = parseLeague(from: document) else {
                error = "Failed to load league data."
                return false
            }

            // Check if already a member
            if league.memberIds.contains(userId) {
                error = "You're already a member of this league."
                return false
            }

            // Check if league is full
            if league.isFull {
                error = "This league is full."
                return false
            }

            // Check if draft has already started
            if league.draftStatus != .pending && league.draftStatus != .scheduled {
                error = "Cannot join - the draft has already started."
                return false
            }

            // Add user to league
            try await db.collection("leagues").document(league.id).updateData([
                "memberIds": FieldValue.arrayUnion([userId]),
                "updatedAt": FieldValue.serverTimestamp()
            ])

            // Update user's league count
            try await db.collection("users").document(userId).updateData([
                "totalLeagues": FieldValue.increment(Int64(1))
            ])

            successMessage = "Successfully joined \(league.name)!"
            return true

        } catch {
            self.error = "Failed to join league: \(error.localizedDescription)"
            return false
        }
    }

    func leaveLeague(_ league: FFLeague) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }

        // Commissioner can't leave their own league
        if league.commissionerId == userId {
            error = "As commissioner, you must transfer ownership or delete the league."
            return false
        }

        do {
            try await db.collection("leagues").document(league.id).updateData([
                "memberIds": FieldValue.arrayRemove([userId]),
                "updatedAt": FieldValue.serverTimestamp()
            ])

            // Update user's league count
            try await db.collection("users").document(userId).updateData([
                "totalLeagues": FieldValue.increment(Int64(-1))
            ])

            successMessage = "You have left \(league.name)"
            return true
        } catch {
            self.error = "Failed to leave league: \(error.localizedDescription)"
            return false
        }
    }

    func deleteLeague(_ league: FFLeague) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }

        guard league.commissionerId == userId else {
            error = "Only the commissioner can delete this league."
            return false
        }

        do {
            try await db.collection("leagues").document(league.id).delete()

            // Update league count for all members
            for memberId in league.memberIds {
                try? await db.collection("users").document(memberId).updateData([
                    "totalLeagues": FieldValue.increment(Int64(-1))
                ])
            }

            successMessage = "League deleted successfully"
            return true
        } catch {
            self.error = "Failed to delete league: \(error.localizedDescription)"
            return false
        }
    }

    func scheduleDraft(for league: FFLeague, at date: Date) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }

        guard league.commissionerId == userId else {
            error = "Only the commissioner can schedule the draft."
            return false
        }

        do {
            try await db.collection("leagues").document(league.id).updateData([
                "draftScheduledAt": Timestamp(date: date),
                "draftStatus": DraftStatus.scheduled.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])

            successMessage = "Draft scheduled!"
            return true
        } catch {
            self.error = "Failed to schedule draft: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Helper Methods

    private func parseLeague(from document: DocumentSnapshot) -> FFLeague? {
        guard let data = document.data() else { return nil }

        let settingsData = data["settings"] as? [String: Any] ?? [:]
        let filtersData = settingsData["movieFilters"] as? [String: Any] ?? [:]

        let movieFilters = MovieFilterSettings(
            theatricalOnly: filtersData["theatricalOnly"] as? Bool ?? true,
            minimumBudget: filtersData["minimumBudget"] as? Int,
            excludedGenreIds: filtersData["excludedGenreIds"] as? [Int] ?? []
        )

        let settings = LeagueSettings(
            draftType: DraftType(rawValue: settingsData["draftType"] as? String ?? "") ?? .serpentine,
            draftOrderType: DraftOrderType(rawValue: settingsData["draftOrderType"] as? String ?? "") ?? .random,
            manualDraftOrder: settingsData["manualDraftOrder"] as? [String],
            scoringMode: ScoringMode(rawValue: settingsData["scoringMode"] as? String ?? "") ?? .boxOfficeWorldwide,
            scoringDirection: ScoringDirection(rawValue: settingsData["scoringDirection"] as? String ?? "") ?? .highest,
            moviesPerPlayer: settingsData["moviesPerPlayer"] as? Int ?? 5,
            pickTimerSeconds: settingsData["pickTimerSeconds"] as? Int ?? 120,
            allowTrading: settingsData["allowTrading"] as? Bool ?? false,
            tradeReviewPeriodDays: settingsData["tradeReviewPeriodDays"] as? Int ?? 1,
            includeOscarPredictions: settingsData["includeOscarPredictions"] as? Bool ?? false,
            oscarBonusMultiplier: settingsData["oscarBonusMultiplier"] as? Double ?? 1.5,
            movieFilters: movieFilters
        )

        let draftScheduledAt: Date?
        if let timestamp = data["draftScheduledAt"] as? Timestamp {
            draftScheduledAt = timestamp.dateValue()
        } else {
            draftScheduledAt = nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let updatedAt: Date
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue()
        } else {
            updatedAt = Date()
        }

        return FFLeague(
            id: document.documentID,
            name: data["name"] as? String ?? "Unknown League",
            description: data["description"] as? String,
            imageURL: (data["imageURL"] as? String).flatMap { URL(string: $0) },
            settings: settings,
            commissionerId: data["commissionerId"] as? String ?? "",
            memberIds: data["memberIds"] as? [String] ?? [],
            maxMembers: data["maxMembers"] as? Int ?? 8,
            inviteCode: data["inviteCode"] as? String ?? "",
            isPublic: data["isPublic"] as? Bool ?? false,
            draftStatus: DraftStatus(rawValue: data["draftStatus"] as? String ?? "") ?? .pending,
            draftScheduledAt: draftScheduledAt,
            draftId: data["draftId"] as? String,
            seasonYear: data["seasonYear"] as? Int ?? Calendar.current.component(.year, from: Date()),
            isSeasonComplete: data["isSeasonComplete"] as? Bool ?? false,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func clearMessages() {
        error = nil
        successMessage = nil
    }
}
