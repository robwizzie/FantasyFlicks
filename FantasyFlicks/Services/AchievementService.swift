//
//  AchievementService.swift
//  FantasyFlicks
//
//  Defines the Movie-Night-focused achievement catalog, tracks unlock progress
//  from the live SeenMoviesService snapshot, and notifies listeners when a new
//  achievement is unlocked so the UI can fire a celebration overlay.
//

import Foundation
import SwiftUI
import Combine

/// A single achievement definition.
struct AchievementDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    /// How to display the unlock requirement to the user (e.g. "10 reviews").
    let goalText: String
    /// Target number to reach for unlock. Nil means a one-shot event (no numeric progress).
    let goal: Int?
}

/// A display-ready snapshot of a single achievement with current progress.
struct AchievementProgress: Identifiable, Hashable {
    let definition: AchievementDefinition
    let current: Int
    let isUnlocked: Bool
    let unlockedAt: Date?

    var id: String { definition.id }
    var progressFraction: Double {
        guard let goal = definition.goal, goal > 0 else { return isUnlocked ? 1 : 0 }
        return min(1.0, Double(current) / Double(goal))
    }
}

@MainActor
final class AchievementService: ObservableObject {

    static let shared = AchievementService()

    /// The full catalog — Movie Night + solo tracking only, no league/draft ones.
    static let catalog: [AchievementDefinition] = [
        AchievementDefinition(
            id: "first_swipe",
            name: "First Pick",
            description: "Complete your first Movie Night swipe",
            icon: "hand.tap.fill",
            goalText: "1 swipe",
            goal: 1
        ),
        AchievementDefinition(
            id: "critic",
            name: "Critic",
            description: "Write 10 reviews with your thoughts",
            icon: "square.and.pencil",
            goalText: "10 reviews",
            goal: 10
        ),
        AchievementDefinition(
            id: "marathoner",
            name: "Marathoner",
            description: "Watch 50 movies",
            icon: "figure.run",
            goalText: "50 watched",
            goal: 50
        ),
        AchievementDefinition(
            id: "completionist",
            name: "Completionist",
            description: "Rate 100 movies",
            icon: "checkmark.seal.fill",
            goalText: "100 rated",
            goal: 100
        ),
        AchievementDefinition(
            id: "picky",
            name: "Picky",
            description: "Give a movie a 5-star rating",
            icon: "star.fill",
            goalText: "1 five-star rating",
            goal: 1
        ),
        AchievementDefinition(
            id: "watchlist_warrior",
            name: "Watchlist Warrior",
            description: "Add 25 movies to your watchlist",
            icon: "bookmark.fill",
            goalText: "25 on watchlist",
            goal: 25
        ),
        AchievementDefinition(
            id: "connoisseur",
            name: "Connoisseur",
            description: "Log movies from 5 different decades",
            icon: "film.stack.fill",
            goalText: "5 decades",
            goal: 5
        ),
        AchievementDefinition(
            id: "social_viewer",
            name: "Social Viewer",
            description: "Add 3 friends",
            icon: "person.3.fill",
            goalText: "3 friends",
            goal: 3
        ),
        AchievementDefinition(
            id: "letterboxd_convert",
            name: "Letterboxd Convert",
            description: "Import your data from Letterboxd",
            icon: "square.and.arrow.down.fill",
            goalText: "1 import",
            goal: 1
        ),
        AchievementDefinition(
            id: "night_owl",
            name: "Night Owl",
            description: "Log a movie you watched between midnight and 6am",
            icon: "moon.stars.fill",
            goalText: "1 late-night log",
            goal: 1
        )
    ]

    // MARK: - Published

    /// The set of unlocked achievement IDs. Persisted in UserDefaults and
    /// mirrored to the user's Firestore doc via ProfileViewModel on unlock.
    @Published private(set) var unlockedIds: Set<String> = []
    @Published private(set) var unlockedAt: [String: Date] = [:]

    /// Fires when a new achievement unlocks so UI can show a celebration.
    /// Multiple unlocks queue up in the array.
    @Published var pendingCelebrations: [AchievementDefinition] = []

    // MARK: - Private

    private let unlockedKey = "ff_achievements_unlocked"
    private let unlockedAtKey = "ff_achievements_unlocked_at"

    private init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        let ids = UserDefaults.standard.array(forKey: unlockedKey) as? [String] ?? []
        unlockedIds = Set(ids)
        if let dict = UserDefaults.standard.dictionary(forKey: unlockedAtKey) as? [String: Double] {
            unlockedAt = dict.reduce(into: [:]) { $0[$1.key] = Date(timeIntervalSince1970: $1.value) }
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(unlockedIds), forKey: unlockedKey)
        let dict = unlockedAt.reduce(into: [String: Double]()) { $0[$1.key] = $1.value.timeIntervalSince1970 }
        UserDefaults.standard.set(dict, forKey: unlockedAtKey)
    }

    // MARK: - Current progress

    /// Compute the current progress for every achievement from the live state
    /// of SeenMoviesService + FriendsService. Pass nil for either to use the
    /// shared singletons — defaults can't reference MainActor state directly.
    func allProgress(
        seen: SeenMoviesService? = nil,
        friendCount: Int? = nil
    ) -> [AchievementProgress] {
        let seenService = seen ?? SeenMoviesService.shared
        let friends = friendCount ?? FriendsService.shared.friends.count
        return Self.catalog.map { def in
            let current = currentProgress(for: def, seen: seenService, friendCount: friends)
            return AchievementProgress(
                definition: def,
                current: current,
                isUnlocked: unlockedIds.contains(def.id),
                unlockedAt: unlockedAt[def.id]
            )
        }
    }

    private func currentProgress(for def: AchievementDefinition, seen: SeenMoviesService, friendCount: Int) -> Int {
        switch def.id {
        case "first_swipe":
            // Best approximation: if they have any seen IDs the ViewModel logged while swiping,
            // count at least one. Otherwise 0.
            return min(1, seen.seenTmdbIds.count)
        case "critic":
            return seen.diary.filter { ($0.reviewText?.isEmpty == false) }.count
        case "marathoner":
            return seen.seenTmdbIds.count
        case "completionist":
            return seen.ratings.count
        case "picky":
            return seen.ratings.values.contains(where: { $0 >= 5.0 }) ? 1 : 0
        case "watchlist_warrior":
            return seen.watchlist.count
        case "connoisseur":
            let decades = Set(seen.diary.compactMap { entry -> Int? in
                let year = Calendar.current.component(.year, from: entry.watchedDate)
                return (year / 10) * 10
            })
            return decades.count
        case "social_viewer":
            return friendCount
        case "letterboxd_convert":
            // Set by caller when an import completes.
            return unlockedIds.contains("letterboxd_convert") ? 1 : 0
        case "night_owl":
            let hasLateNight = seen.diary.contains { entry in
                let hour = Calendar.current.component(.hour, from: entry.watchedDate)
                return hour < 6
            }
            return hasLateNight ? 1 : 0
        default:
            return 0
        }
    }

    // MARK: - Unlock evaluation

    /// Check every achievement against current state and queue celebrations
    /// for any that just transitioned to unlocked. Call this after any state
    /// mutation (rating, diary add, friend add, import, etc.). Pass nil to
    /// use the shared singletons — defaults can't reference MainActor state.
    func evaluateUnlocks(
        seen: SeenMoviesService? = nil,
        friendCount: Int? = nil
    ) {
        let seenService = seen ?? SeenMoviesService.shared
        let friends = friendCount ?? FriendsService.shared.friends.count
        for def in Self.catalog where !unlockedIds.contains(def.id) {
            let progress = currentProgress(for: def, seen: seenService, friendCount: friends)
            if let goal = def.goal, progress >= goal {
                unlock(def)
            }
        }
    }

    /// Mark a one-shot achievement unlocked directly (used by e.g. successful Letterboxd import).
    func forceUnlock(_ achievementId: String) {
        guard let def = Self.catalog.first(where: { $0.id == achievementId }),
              !unlockedIds.contains(achievementId) else { return }
        unlock(def)
    }

    private func unlock(_ def: AchievementDefinition) {
        unlockedIds.insert(def.id)
        unlockedAt[def.id] = Date()
        pendingCelebrations.append(def)
        save()
    }

    /// Called by the celebration overlay when it finishes showing.
    func dequeueCelebration(_ def: AchievementDefinition) {
        pendingCelebrations.removeAll { $0.id == def.id }
    }
}
