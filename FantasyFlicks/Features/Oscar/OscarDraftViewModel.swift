//
//  OscarDraftViewModel.swift
//  FantasyFlicks
//
//  Manages Oscar draft/prediction data with Firestore sync
//

import Foundation
import SwiftUI
import FirebaseFirestore
import Combine

@MainActor
final class OscarDraftViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var nominees: [OscarNominee] = []
    @Published private(set) var picks: [OscarPick] = []
    @Published private(set) var allPicks: [OscarPick] = [] // All picks in the league
    @Published private(set) var standings: [OscarStanding] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmittingPick = false
    @Published private(set) var draftStatus: DraftStatus = .pending
    @Published private(set) var currentPickerId: String?
    @Published private(set) var currentCategoryId: String?
    @Published private(set) var currentRound: Int = 1
    @Published private(set) var draftOrder: [String] = []
    @Published private(set) var totalRounds: Int = 5
    @Published private(set) var remainingTime: Int = 0
    @Published private(set) var pickTimerSeconds: Int = 0
    @Published private(set) var oscarSettings: OscarModeSettings?
    @Published var error: String?

    // MARK: - Computed Properties

    var myPicks: [OscarPick] {
        guard let userId = authService.currentUser?.id else { return [] }
        return picks.filter { $0.userId == userId }
    }

    var isMyTurn: Bool {
        currentPickerId == authService.currentUser?.id && draftStatus == .inProgress
    }

    var currentCategory: OscarCategory? {
        guard let id = currentCategoryId else { return nil }
        return OscarCategory.category(for: id)
    }

    /// Categories available for picking (based on draft style)
    var availableCategories: [OscarCategory] {
        guard let settings = oscarSettings else { return OscarCategory.allCategories }

        if settings.draftStyle == .categoryRounds {
            // In category rounds mode, only the current category is available
            if let catId = currentCategoryId, let cat = OscarCategory.category(for: catId) {
                return [cat]
            }
            return []
        }

        // In anyCategory mode, show all categories
        // Filter out categories the user already picked (unless duplicates allowed)
        if !settings.allowDuplicatePicks {
            let pickedCategoryIds = Set(myPicks.map { $0.categoryId })
            return OscarCategory.allCategories.filter { !pickedCategoryIds.contains($0.id) }
        }

        return OscarCategory.allCategories
    }

    /// Nominees for a specific category
    func nominees(for categoryId: String) -> [OscarNominee] {
        nominees.filter { $0.categoryId == categoryId }
    }

    /// Check if a nominee has been picked (by anyone, in non-duplicate mode)
    func isNomineePicked(_ nomineeId: String, in categoryId: String) -> Bool {
        guard let settings = oscarSettings else { return false }
        if settings.allowDuplicatePicks { return false }
        return allPicks.contains { $0.nomineeId == nomineeId && $0.categoryId == categoryId }
    }

    /// Check if the current user already picked in a category
    func hasPickedCategory(_ categoryId: String) -> Bool {
        myPicks.contains { $0.categoryId == categoryId }
    }

    var totalPicksMade: Int { allPicks.count }
    var totalPicksNeeded: Int { draftOrder.count * totalRounds }
    var isDraftComplete: Bool { draftStatus == .completed }

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private let authService = AuthenticationService.shared
    private var draftListener: ListenerRegistration?
    private var picksListener: ListenerRegistration?
    private var nomineesListener: ListenerRegistration?
    private var timerCancellable: AnyCancellable?

    // MARK: - Initialization

    deinit {
        draftListener?.remove()
        picksListener?.remove()
        nomineesListener?.remove()
        timerCancellable?.cancel()
    }

    // MARK: - Load Draft

    func loadOscarDraft(leagueId: String, draftId: String) async {
        isLoading = true
        defer { isLoading = false }

        // Listen to the draft document
        draftListener?.remove()
        draftListener = db.collection("drafts").document(draftId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let error = error {
                        self.error = error.localizedDescription
                        return
                    }
                    guard let data = snapshot?.data() else { return }

                    self.draftStatus = DraftStatus(rawValue: data["status"] as? String ?? "") ?? .pending
                    self.currentPickerId = data["currentPickerId"] as? String
                    self.currentCategoryId = data["currentCategoryId"] as? String
                    self.currentRound = data["currentRound"] as? Int ?? 1
                    self.draftOrder = data["draftOrder"] as? [String] ?? []
                    self.totalRounds = data["totalRounds"] as? Int ?? 5
                    self.pickTimerSeconds = data["pickTimerSeconds"] as? Int ?? 0

                    // Parse Oscar settings if present
                    if let settingsData = data["oscarSettings"] as? [String: Any] {
                        self.oscarSettings = OscarModeSettings(
                            draftStyle: OscarDraftStyle(rawValue: settingsData["draftStyle"] as? String ?? "") ?? .anyCategory,
                            allowDuplicatePicks: settingsData["allowDuplicatePicks"] as? Bool ?? false,
                            lockAtCeremonyStart: settingsData["lockAtCeremonyStart"] as? Bool ?? true,
                            allowPreCeremonyMoves: settingsData["allowPreCeremonyMoves"] as? Bool ?? true,
                            ceremonyDate: (settingsData["ceremonyDate"] as? Timestamp)?.dateValue(),
                            pointsPerCorrectPick: settingsData["pointsPerCorrectPick"] as? Double ?? 1.0,
                            categoryBonusPoints: settingsData["categoryBonusPoints"] as? Double ?? 2.0
                        )
                    }

                    // Handle timer
                    if self.draftStatus == .inProgress && self.pickTimerSeconds > 0 {
                        if let startTimestamp = data["pickTimerStartedAt"] as? Timestamp {
                            let elapsed = Int(Date().timeIntervalSince(startTimestamp.dateValue()))
                            self.remainingTime = max(0, self.pickTimerSeconds - elapsed)
                            self.startPickTimer()
                        }
                    } else {
                        self.timerCancellable?.cancel()
                        self.remainingTime = 0
                    }
                }
            }

        // Listen to picks
        picksListener?.remove()
        picksListener = db.collection("drafts").document(draftId)
            .collection("picks")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    if let error = error {
                        self.error = error.localizedDescription
                        return
                    }
                    guard let documents = snapshot?.documents else { return }

                    let allPicks = documents.compactMap { doc -> OscarPick? in
                        let data = doc.data()
                        return OscarPick(
                            id: doc.documentID,
                            leagueId: leagueId,
                            teamId: data["teamId"] as? String ?? "",
                            userId: data["userId"] as? String ?? "",
                            categoryId: data["categoryId"] as? String ?? "",
                            nomineeId: data["nomineeId"] as? String ?? "",
                            nomineeName: data["nomineeName"] as? String ?? "",
                            movieTitle: data["movieTitle"] as? String,
                            pickedAt: (data["pickedAt"] as? Timestamp)?.dateValue() ?? Date(),
                            isCorrect: data["isCorrect"] as? Bool,
                            pointsEarned: data["pointsEarned"] as? Double
                        )
                    }

                    self.allPicks = allPicks
                    if let userId = self.authService.currentUser?.id {
                        self.picks = allPicks.filter { $0.userId == userId }
                    }

                    // Compute standings
                    self.computeStandings(allPicks: allPicks)
                }
            }

        // Load nominees
        await loadNominees(year: Calendar.current.component(.year, from: Date()))
    }

    // MARK: - Search & Filter

    @Published var searchQuery: String = ""
    @Published var categoryFilter: String? = nil // nil = show all
    @Published var showFrontrunnerOnly: Bool = false

    /// Filtered nominees based on search, category filter, and frontrunner toggle
    var filteredNominees: [OscarNominee] {
        var result = nominees

        // Category filter
        if let catFilter = categoryFilter {
            result = result.filter { $0.categoryId == catFilter }
        }

        // Search
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                ($0.movieTitle?.lowercased().contains(q) ?? false) ||
                ($0.details?.lowercased().contains(q) ?? false)
            }
        }

        // Frontrunner filter
        if showFrontrunnerOnly {
            result = result.filter { $0.isFrontrunner }
        }

        return result
    }

    /// Get filtered nominees for a specific category
    func filteredNominees(for categoryId: String) -> [OscarNominee] {
        var result = nominees(for: categoryId)

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                ($0.movieTitle?.lowercased().contains(q) ?? false)
            }
        }

        return result
    }

    // MARK: - Roster Percentage

    /// How many teams in this draft have picked a specific nominee
    func rosterPercentage(for nomineeId: String, categoryId: String) -> Double {
        let totalTeams = draftOrder.count
        guard totalTeams > 0 else { return 0 }
        let pickedCount = allPicks.filter { $0.nomineeId == nomineeId && $0.categoryId == categoryId }.count
        return Double(pickedCount) / Double(totalTeams)
    }

    func rosterPercentageString(for nomineeId: String, categoryId: String) -> String {
        let pct = rosterPercentage(for: nomineeId, categoryId: categoryId)
        return "\(Int(pct * 100))%"
    }

    // MARK: - Load Nominees

    func loadNominees(year: Int) async {
        // Use bundled 97th Academy Award nominees as primary data source
        nominees = OscarNominee.nominees97th

        // Also sync from Firestore for real-time winner updates during ceremony
        OscarDataService.shared.syncFromFirestore(year: year)
    }

    // MARK: - Submit Pick

    func submitOscarPick(categoryId: String, nominee: OscarNominee, draftId: String, leagueId: String) async -> Bool {
        guard let userId = authService.currentUser?.id else {
            error = "You must be signed in"
            return false
        }

        guard isMyTurn else {
            error = "It's not your turn to pick"
            return false
        }

        isSubmittingPick = true
        defer { isSubmittingPick = false }

        let pickId = UUID().uuidString
        let pickData: [String: Any] = [
            "leagueId": leagueId,
            "teamId": userId,
            "userId": userId,
            "categoryId": categoryId,
            "nomineeId": nominee.id,
            "nomineeName": nominee.displayName,
            "movieTitle": nominee.movieTitle as Any,
            "pickedAt": FieldValue.serverTimestamp(),
            "overallPickNumber": totalPicksMade + 1,
            "roundNumber": currentRound,
            "wasAutoPick": false
        ]

        do {
            // Add pick to subcollection
            try await db.collection("drafts").document(draftId)
                .collection("picks").document(pickId).setData(pickData)

            // Calculate next state
            let nextState = calculateNextOscarDraftState(draftId: draftId)
            try await db.collection("drafts").document(draftId).updateData(nextState)

            return true
        } catch {
            self.error = "Failed to submit pick: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Start Oscar Draft

    func startOscarDraft(leagueId: String) async -> String? {
        guard authService.currentUser?.id != nil else { return nil }

        do {
            let leagueDoc = try await db.collection("leagues").document(leagueId).getDocument()
            guard let leagueData = leagueDoc.data() else { return nil }

            let memberIds = leagueData["memberIds"] as? [String] ?? []
            let settingsData = leagueData["settings"] as? [String: Any] ?? [:]
            let draftType = DraftType(rawValue: settingsData["draftType"] as? String ?? "") ?? .serpentine
            let moviesPerPlayer = settingsData["moviesPerPlayer"] as? Int ?? 5
            let pickTimerSeconds = settingsData["pickTimerSeconds"] as? Int ?? 0

            // Parse Oscar settings
            let oscarSettingsData = settingsData["oscarSettings"] as? [String: Any] ?? [:]
            let draftStyle = OscarDraftStyle(rawValue: oscarSettingsData["draftStyle"] as? String ?? "") ?? .anyCategory

            let draftOrder = memberIds.shuffled()
            let draftId = UUID().uuidString

            var draftData: [String: Any] = [
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
                "isOscarDraft": true,
                "createdAt": FieldValue.serverTimestamp(),
                "startedAt": FieldValue.serverTimestamp(),
                "oscarSettings": [
                    "draftStyle": draftStyle.rawValue,
                    "allowDuplicatePicks": oscarSettingsData["allowDuplicatePicks"] as? Bool ?? false,
                    "lockAtCeremonyStart": oscarSettingsData["lockAtCeremonyStart"] as? Bool ?? true,
                    "allowPreCeremonyMoves": oscarSettingsData["allowPreCeremonyMoves"] as? Bool ?? true,
                    "pointsPerCorrectPick": oscarSettingsData["pointsPerCorrectPick"] as? Double ?? 1.0,
                    "categoryBonusPoints": oscarSettingsData["categoryBonusPoints"] as? Double ?? 2.0
                ]
            ]

            // Add timer start if time limit is set
            if pickTimerSeconds > 0 {
                draftData["pickTimerStartedAt"] = FieldValue.serverTimestamp()
            }

            // For category rounds, set the first category
            if draftStyle == .categoryRounds {
                draftData["currentCategoryId"] = OscarCategory.allCategories.first?.id ?? "best_picture"
            }

            try await db.collection("drafts").document(draftId).setData(draftData)

            // Update league
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

    // MARK: - Private Methods

    private func calculateNextOscarDraftState(draftId: String) -> [String: Any] {
        let totalPlayers = draftOrder.count
        guard totalPlayers > 0 else { return [:] }

        let nextOverallPick = totalPicksMade + 2 // +1 for current pick, +1 for next

        // Check if draft is complete
        if nextOverallPick > totalPicksNeeded {
            var completedState: [String: Any] = [
                "status": DraftStatus.completed.rawValue,
                "currentOverallPick": nextOverallPick,
                "completedAt": FieldValue.serverTimestamp(),
                "pickCount": totalPicksMade + 1
            ]
            completedState["currentPickerId"] = NSNull()
            return completedState
        }

        let nextRound = ((nextOverallPick - 1) / totalPlayers) + 1
        let nextPickInRound = ((nextOverallPick - 1) % totalPlayers) + 1

        // Serpentine draft order
        let nextPickerIndex: Int
        let draftType = DraftType.serpentine // Oscar drafts use serpentine by default
        if draftType == .serpentine && nextRound % 2 == 0 {
            nextPickerIndex = totalPlayers - nextPickInRound
        } else {
            nextPickerIndex = nextPickInRound - 1
        }

        let nextPickerId = draftOrder[nextPickerIndex]

        var nextState: [String: Any] = [
            "currentRound": nextRound,
            "currentPickInRound": nextPickInRound,
            "currentOverallPick": nextOverallPick - 1,
            "currentPickerId": nextPickerId,
            "pickCount": totalPicksMade + 1
        ]

        // For category rounds, advance to next category when round changes
        if oscarSettings?.draftStyle == .categoryRounds && nextRound != currentRound {
            let categories = OscarCategory.allCategories
            let currentIndex = categories.firstIndex(where: { $0.id == currentCategoryId }) ?? 0
            let nextCategoryIndex = min(currentIndex + 1, categories.count - 1)
            nextState["currentCategoryId"] = categories[nextCategoryIndex].id
        }

        if pickTimerSeconds > 0 {
            nextState["pickTimerStartedAt"] = FieldValue.serverTimestamp()
        }

        return nextState
    }

    private func startPickTimer() {
        timerCancellable?.cancel()

        guard pickTimerSeconds > 0, remainingTime > 0 else { return }

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.remainingTime > 0 {
                    self.remainingTime -= 1
                } else {
                    self.timerCancellable?.cancel()
                }
            }
    }

    private func computeStandings(allPicks: [OscarPick]) {
        // Group picks by user
        let grouped = Dictionary(grouping: allPicks, by: { $0.userId })

        var newStandings: [OscarStanding] = []
        for (userId, userPicks) in grouped {
            let correctPicks = userPicks.filter { $0.isCorrect == true }.count
            let totalPoints = userPicks.compactMap { $0.pointsEarned }.reduce(0, +)

            newStandings.append(OscarStanding(
                teamId: userId,
                userId: userId,
                teamName: "Team \(userId.prefix(6))",
                rank: 0,
                correctPicks: correctPicks,
                totalPicks: userPicks.count,
                totalPoints: totalPoints,
                maxPossiblePoints: Double(userPicks.count) * (oscarSettings?.pointsPerCorrectPick ?? 1.0)
            ))
        }

        // Sort by points then correct picks
        newStandings.sort { a, b in
            if a.totalPoints != b.totalPoints { return a.totalPoints > b.totalPoints }
            return a.correctPicks > b.correctPicks
        }

        // Assign ranks
        for i in 0..<newStandings.count {
            newStandings[i].rank = i + 1
        }

        standings = newStandings
    }
}
