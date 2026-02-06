//
//  OscarDataService.swift
//  FantasyFlicks
//
//  Manages Oscar nominee data, odds, roster percentages, and ADP
//  Uses bundled data as primary source, with Firestore for real-time updates
//

import Foundation
import FirebaseFirestore

@MainActor
final class OscarDataService: ObservableObject {

    // MARK: - Singleton

    static let shared = OscarDataService()

    // MARK: - Published Properties

    @Published private(set) var nominees: [OscarNominee] = []
    @Published private(set) var rosterPercentages: [String: OscarRosterPercentage] = [:]
    @Published private(set) var averageDraftPositions: [String: Double] = [:]
    @Published private(set) var isLoading = false

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private var nomineesListener: ListenerRegistration?

    // MARK: - Initialization

    private init() {
        loadBundledNominees()
    }

    deinit {
        nomineesListener?.remove()
    }

    // MARK: - Load Nominees

    /// Load nominees from bundled data (primary) and optionally sync with Firestore
    func loadBundledNominees() {
        nominees = OscarNominee.nominees97th
    }

    /// Sync nominees from Firestore (for real-time winner updates during ceremony)
    func syncFromFirestore(year: Int) {
        nomineesListener?.remove()

        nomineesListener = db.collection("oscarNominees")
            .whereField("year", isEqualTo: year)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                    // Merge Firestore data with bundled data (Firestore wins for isWinner)
                    var updatedNominees = self.nominees
                    for doc in documents {
                        let data = doc.data()
                        guard let name = data["name"] as? String,
                              let categoryId = data["categoryId"] as? String else { continue }

                        if let index = updatedNominees.firstIndex(where: { $0.name == name && $0.categoryId == categoryId }) {
                            if let isWinner = data["isWinner"] as? Bool {
                                updatedNominees[index].isWinner = isWinner
                            }
                            if let timestamp = data["winnerAnnouncedAt"] as? Timestamp {
                                updatedNominees[index].winnerAnnouncedAt = timestamp.dateValue()
                            }
                        }
                    }
                    self.nominees = updatedNominees
                }
            }
    }

    // MARK: - Nominees Query

    /// Get nominees for a specific category
    func nominees(for categoryId: String) -> [OscarNominee] {
        nominees.filter { $0.categoryId == categoryId }
    }

    /// Search nominees by name or movie title
    func searchNominees(_ query: String) -> [OscarNominee] {
        guard !query.isEmpty else { return nominees }
        let lowered = query.lowercased()
        return nominees.filter {
            $0.name.lowercased().contains(lowered) ||
            ($0.movieTitle?.lowercased().contains(lowered) ?? false) ||
            ($0.details?.lowercased().contains(lowered) ?? false)
        }
    }

    /// Search nominees within a specific category
    func searchNominees(_ query: String, in categoryId: String) -> [OscarNominee] {
        guard !query.isEmpty else { return nominees(for: categoryId) }
        return searchNominees(query).filter { $0.categoryId == categoryId }
    }

    /// Get nominees filtered by category type
    func nominees(majorOnly: Bool) -> [OscarNominee] {
        let categoryIds = Set(
            (majorOnly ? OscarCategory.majorCategories : OscarCategory.allCategories).map { $0.id }
        )
        return nominees.filter { categoryIds.contains($0.categoryId) }
    }

    // MARK: - Odds

    /// Get odds for a specific nominee
    func odds(for nominee: OscarNominee) -> Double? {
        nominee.odds
    }

    /// Get all nominees in a category sorted by odds (frontrunner first)
    func nomineesByOdds(for categoryId: String) -> [OscarNominee] {
        nominees(for: categoryId).sorted { ($0.odds ?? 0) > ($1.odds ?? 0) }
    }

    // MARK: - Roster Percentage

    /// Compute roster percentages for a specific league
    func computeRosterPercentages(leagueId: String, allPicks: [OscarPick], totalTeams: Int) {
        var percentages: [String: OscarRosterPercentage] = [:]

        // Group picks by nominee
        let picksByNominee = Dictionary(grouping: allPicks, by: { "\($0.categoryId)_\($0.nomineeId)" })

        for nominee in nominees {
            let key = "\(nominee.categoryId)_\(nominee.id)"
            let pickedCount = picksByNominee[key]?.count ?? 0

            percentages[key] = OscarRosterPercentage(
                nomineeId: nominee.id,
                categoryId: nominee.categoryId,
                leagueId: leagueId,
                pickedCount: pickedCount,
                totalTeams: totalTeams,
                updatedAt: Date()
            )
        }

        rosterPercentages = percentages
    }

    /// Get roster percentage for a specific nominee in a league
    func rosterPercentage(for nomineeId: String, categoryId: String) -> OscarRosterPercentage? {
        rosterPercentages["\(categoryId)_\(nomineeId)"]
    }

    // MARK: - Average Draft Position (ADP)

    /// Compute ADP from historical picks across all leagues
    func computeADP(from allLeaguePicks: [[OscarPick]]) {
        var totalPosition: [String: Double] = [:]
        var pickCount: [String: Int] = [:]

        for leaguePicks in allLeaguePicks {
            let sorted = leaguePicks.sorted { $0.pickedAt < $1.pickedAt }
            for (index, pick) in sorted.enumerated() {
                let key = "\(pick.categoryId)_\(pick.nomineeId)"
                totalPosition[key, default: 0] += Double(index + 1)
                pickCount[key, default: 0] += 1
            }
        }

        var adp: [String: Double] = [:]
        for (key, total) in totalPosition {
            if let count = pickCount[key], count > 0 {
                adp[key] = total / Double(count)
            }
        }

        averageDraftPositions = adp
    }

    /// Get ADP for a specific nominee
    func adp(for nomineeId: String, categoryId: String) -> Double? {
        averageDraftPositions["\(categoryId)_\(nomineeId)"]
    }

    /// Get formatted ADP string
    func adpString(for nomineeId: String, categoryId: String) -> String? {
        guard let adp = adp(for: nomineeId, categoryId: categoryId) else { return nil }
        return String(format: "%.1f", adp)
    }

    // MARK: - Upload Nominees to Firestore

    /// Upload bundled nominees to Firestore (admin function)
    func uploadNomineesToFirestore() async throws {
        let batch = db.batch()

        for nominee in nominees {
            let ref = db.collection("oscarNominees").document(nominee.id)
            var data: [String: Any] = [
                "year": nominee.year,
                "categoryId": nominee.categoryId,
                "name": nominee.name,
                "isWinner": nominee.isWinner,
            ]
            if let movieTitle = nominee.movieTitle {
                data["movieTitle"] = movieTitle
            }
            if let movieId = nominee.movieId {
                data["movieId"] = movieId
            }
            if let posterPath = nominee.posterPath {
                data["posterPath"] = posterPath
            }
            if let details = nominee.details {
                data["details"] = details
            }
            batch.setData(data, forDocument: ref)
        }

        try await batch.commit()
    }
}
