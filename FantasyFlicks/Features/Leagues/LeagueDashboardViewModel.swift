//
//  LeagueDashboardViewModel.swift
//  FantasyFlicks
//
//  Manages league dashboard data and standings
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - League Standing Model

struct LeagueStanding: Identifiable, Hashable {
    var id: String { teamId }

    let teamId: String
    let userId: String
    let teamName: String
    var rank: Int
    let totalScore: Double
    let movieCount: Int
    let topMovieTitle: String?
    let topMovieScore: Double?

    // Oscar-specific fields
    let correctPicks: Int
    let totalPicks: Int

    var accuracy: Double {
        guard totalPicks > 0 else { return 0 }
        return Double(correctPicks) / Double(totalPicks)
    }

    init(
        teamId: String,
        userId: String,
        teamName: String,
        rank: Int,
        totalScore: Double,
        movieCount: Int = 0,
        topMovieTitle: String? = nil,
        topMovieScore: Double? = nil,
        correctPicks: Int = 0,
        totalPicks: Int = 0
    ) {
        self.teamId = teamId
        self.userId = userId
        self.teamName = teamName
        self.rank = rank
        self.totalScore = totalScore
        self.movieCount = movieCount
        self.topMovieTitle = topMovieTitle
        self.topMovieScore = topMovieScore
        self.correctPicks = correctPicks
        self.totalPicks = totalPicks
    }
}

// MARK: - View Model

@MainActor
final class LeagueDashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var standings: [LeagueStanding] = []
    @Published private(set) var myTeam: LeagueStanding?
    @Published private(set) var isLoading = false
    @Published var error: String?

    // MARK: - Private Properties

    private let leagueId: String
    private let isOscarMode: Bool
    private let db = Firestore.firestore()
    private let authService = AuthenticationService.shared
    private var standingsListener: ListenerRegistration?

    // MARK: - Initialization

    init(leagueId: String, isOscarMode: Bool) {
        self.leagueId = leagueId
        self.isOscarMode = isOscarMode
    }

    deinit {
        standingsListener?.remove()
    }

    // MARK: - Load Data

    func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }

        if isOscarMode {
            await loadOscarStandings()
        } else {
            await loadBoxOfficeStandings()
        }
    }

    // MARK: - Oscar Standings

    private func loadOscarStandings() async {
        do {
            // Get the league's draft ID
            let leagueDoc = try await db.collection("leagues").document(leagueId).getDocument()
            guard let leagueData = leagueDoc.data(),
                  let draftId = leagueData["draftId"] as? String else {
                standings = []
                return
            }

            // Get draft info
            let draftDoc = try await db.collection("drafts").document(draftId).getDocument()
            guard let draftData = draftDoc.data() else {
                standings = []
                return
            }

            let draftOrder = draftData["draftOrder"] as? [String] ?? []
            let settingsData = leagueData["settings"] as? [String: Any] ?? [:]
            let oscarSettingsData = settingsData["oscarSettings"] as? [String: Any] ?? [:]
            let pointsPerPick = oscarSettingsData["pointsPerCorrectPick"] as? Double ?? 1.0

            // Get all picks
            let picksSnapshot = try await db.collection("drafts").document(draftId)
                .collection("picks")
                .getDocuments()

            // Group picks by user
            var picksByUser: [String: [DocumentSnapshot]] = [:]
            for doc in picksSnapshot.documents {
                let userId = doc.data()["userId"] as? String ?? ""
                picksByUser[userId, default: []].append(doc)
            }

            // Fetch usernames for all users
            var usernames: [String: String] = [:]
            for userId in draftOrder {
                do {
                    let userDoc = try await db.collection("users").document(userId).getDocument()
                    if let data = userDoc.data(),
                       let username = data["username"] as? String {
                        usernames[userId] = username
                    }
                } catch {
                    usernames[userId] = "User"
                }
            }

            // Compute standings
            var newStandings: [LeagueStanding] = []

            for (userId, userPicks) in picksByUser {
                let correctCount = userPicks.filter { ($0.data()["isCorrect"] as? Bool) == true }.count
                let totalCount = userPicks.count
                let points = userPicks.compactMap { $0.data()["pointsEarned"] as? Double }.reduce(0, +)

                let username = usernames[userId] ?? "User"
                let teamName = "Team \(username)"

                newStandings.append(LeagueStanding(
                    teamId: userId,
                    userId: userId,
                    teamName: teamName,
                    rank: 0,
                    totalScore: points,
                    correctPicks: correctCount,
                    totalPicks: totalCount
                ))
            }

            // Sort by score
            newStandings.sort { a, b in
                if a.totalScore != b.totalScore { return a.totalScore > b.totalScore }
                return a.correctPicks > b.correctPicks
            }

            // Assign ranks
            for i in 0..<newStandings.count {
                newStandings[i].rank = i + 1
            }

            standings = newStandings

            // Find my team
            if let userId = authService.currentUser?.id {
                myTeam = standings.first { $0.userId == userId }
            }

        } catch {
            self.error = "Failed to load standings: \(error.localizedDescription)"
            standings = []
        }
    }

    // MARK: - Box Office Standings

    private func loadBoxOfficeStandings() async {
        // Placeholder for box office standings
        // This would fetch team data and movie scores from Firestore
        standings = []
    }
}
