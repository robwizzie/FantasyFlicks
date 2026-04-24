//
//  ProfileViewModel.swift
//  FantasyFlicks
//
//  Manages user profile data with Firebase Auth and Firestore
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var user: FFUser?
    @Published private(set) var recentActivity: [ActivityItem] = []
    @Published private(set) var achievements: [AchievementDisplay] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var error: String?
    @Published var successMessage: String?

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private let authService = AuthenticationService.shared
    private var userListener: ListenerRegistration?

    // MARK: - Types

    struct ActivityItem: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let timestamp: Date

        var timeAgo: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: timestamp, relativeTo: Date())
        }
    }

    struct AchievementDisplay: Identifiable {
        let id: String
        let icon: String
        let name: String
        let description: String
        let isUnlocked: Bool
    }

    // MARK: - Initialization

    init() {
        setupUserListener()
        loadAchievements()
    }

    deinit {
        userListener?.remove()
    }

    // MARK: - Real-time Listener

    private func setupUserListener() {
        guard let userId = authService.currentUser?.id else {
            // Use auth service's user if available
            user = authService.currentUser
            return
        }

        userListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        self.error = error.localizedDescription
                        return
                    }

                    guard let data = snapshot?.data() else { return }
                    self.user = self.parseUser(from: data, id: userId)
                    await self.loadRecentActivity()
                }
            }
    }

    // MARK: - Public Methods

    func refreshProfile() async {
        guard let userId = authService.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let data = document.data() {
                user = parseUser(from: data, id: userId)
            }
            await loadRecentActivity()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateProfile(
        displayName: String?,
        username: String?,
        avatarIcon: String? = nil,
        favoriteGenre: String? = nil,
        bio: String? = nil,
        avatarBase64: String? = nil
    ) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }

        isSaving = true
        defer { isSaving = false }

        var updates: [String: Any] = [:]

        if let displayName = displayName, !displayName.isEmpty {
            updates["displayName"] = displayName
        }

        if let username = username, !username.isEmpty {
            // Check if username changed and is available
            let currentUsername = user?.username ?? ""
            if username.lowercased() != currentUsername.lowercased() {
                let isAvailable = await authService.checkUsernameAvailability(username)
                if !isAvailable {
                    error = "Username is already taken"
                    return false
                }
            }
            updates["username"] = username
            updates["usernameLowercase"] = username.lowercased()
        }

        if let avatarIcon = avatarIcon {
            updates["avatarIcon"] = avatarIcon
        }

        // Uploaded photo (takes precedence over icon when viewed)
        if let avatarBase64 {
            updates["avatarBase64"] = avatarBase64
        } else {
            // Allow clearing the uploaded photo
            updates["avatarBase64"] = NSNull()
        }

        if let favoriteGenre = favoriteGenre {
            updates["favoriteGenre"] = favoriteGenre
        } else {
            updates["favoriteGenre"] = NSNull()
        }

        if let bio = bio, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updates["bio"] = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            updates["bio"] = NSNull()
        }

        guard !updates.isEmpty else { return true }

        do {
            try await db.collection("users").document(userId).updateData(updates)

            // Also update Firebase Auth display name if changed
            if let displayName = displayName, let currentUser = Auth.auth().currentUser {
                let changeRequest = currentUser.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }

            successMessage = "Profile updated successfully"
            return true
        } catch {
            self.error = "Failed to update profile: \(error.localizedDescription)"
            return false
        }
    }

    func updateNotificationSettings(enabled: Bool, reminderMinutes: Int) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }

        do {
            try await db.collection("users").document(userId).updateData([
                "notificationsEnabled": enabled,
                "draftReminderMinutes": reminderMinutes
            ])
            return true
        } catch {
            self.error = "Failed to update settings: \(error.localizedDescription)"
            return false
        }
    }

    /// Replace the user's favorite movie list (Letterboxd-style, max 4).
    func updateFavoriteMovies(_ tmdbIds: [Int]) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        // Cap to 4 like Letterboxd.
        let capped = Array(tmdbIds.prefix(4))
        do {
            try await db.collection("users").document(userId).updateData([
                "favoriteMovieIds": capped
            ])
            // Update local copy for immediate UI refresh.
            if var u = user {
                u.favoriteMovieIds = capped
                user = u
            }
            return true
        } catch {
            self.error = "Failed to update favorites: \(error.localizedDescription)"
            return false
        }
    }

    func updatePrivacySettings(
        diaryPrivate: Bool,
        watchedPrivate: Bool,
        watchlistPrivate: Bool,
        ratingsPrivate: Bool
    ) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }

        do {
            try await db.collection("users").document(userId).updateData([
                "diaryPrivate": diaryPrivate,
                "watchedPrivate": watchedPrivate,
                "watchlistPrivate": watchlistPrivate,
                "ratingsPrivate": ratingsPrivate
            ])
            return true
        } catch {
            self.error = "Failed to update privacy: \(error.localizedDescription)"
            return false
        }
    }

    func signOut() {
        authService.signOut()
        user = nil
        recentActivity = []
    }

    func deleteAccount() async -> Bool {
        guard let userId = authService.currentUser?.id,
              let firebaseUser = Auth.auth().currentUser else {
            return false
        }

        do {
            // Delete user document from Firestore
            try await db.collection("users").document(userId).delete()

            // Delete from Firebase Auth
            try await firebaseUser.delete()

            user = nil
            recentActivity = []
            return true
        } catch {
            self.error = "Failed to delete account: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Friend Management (delegates to FriendsService)

    func addFriend(userId friendId: String) async -> Bool {
        do {
            let friend = try await FriendsService.shared.fetchUser(id: friendId)
            try await FriendsService.shared.addFriend(friend)
            successMessage = "Friend added!"
            return true
        } catch {
            self.error = "Failed to add friend: \(error.localizedDescription)"
            return false
        }
    }

    func removeFriend(userId friendId: String) async -> Bool {
        do {
            try await FriendsService.shared.removeFriend(userId: friendId)
            return true
        } catch {
            self.error = "Failed to remove friend: \(error.localizedDescription)"
            return false
        }
    }

    func blockUser(userId blockedId: String) async -> Bool {
        do {
            try await FriendsService.shared.blockUser(blockedId)
            return true
        } catch {
            self.error = "Failed to block user: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Private Methods

    private func loadRecentActivity() async {
        guard let userId = authService.currentUser?.id else { return }

        // For now, we'll create activity from available data
        // In a full implementation, this would query an activities collection
        var activities: [ActivityItem] = []

        // Check for recent league joins
        do {
            let leaguesSnapshot = try await db.collection("leagues")
                .whereField("memberIds", arrayContains: userId)
                .order(by: "updatedAt", descending: true)
                .limit(to: 3)
                .getDocuments()

            for doc in leaguesSnapshot.documents {
                if let name = doc.data()["name"] as? String,
                   let timestamp = doc.data()["createdAt"] as? Timestamp {
                    activities.append(ActivityItem(
                        icon: "trophy.fill",
                        text: "Joined \(name)",
                        timestamp: timestamp.dateValue()
                    ))
                }
            }
        } catch {
            // Silently fail for activity loading
        }

        // Add achievement activity if user has achievements
        if let user = user, !user.achievementIds.isEmpty {
            activities.append(ActivityItem(
                icon: "star.fill",
                text: "Earned '\(user.achievementIds.first ?? "Achievement")' badge",
                timestamp: Date().addingTimeInterval(-86400)
            ))
        }

        recentActivity = Array(activities.prefix(5))
    }

    private func loadAchievements() {
        // Achievement catalog comes from AchievementService now. We expose a
        // mapped display-friendly array for the existing Profile UI, but the
        // underlying progress / unlock state lives in AchievementService.
        let progress = AchievementService.shared.allProgress()
        achievements = progress.map { p in
            AchievementDisplay(
                id: p.definition.id,
                icon: p.definition.icon,
                name: p.definition.name,
                description: p.definition.description,
                isUnlocked: p.isUnlocked
            )
        }
        // Re-evaluate unlocks whenever the profile screen refreshes.
        AchievementService.shared.evaluateUnlocks()
    }

    private func parseUser(from data: [String: Any], id: String) -> FFUser {
        FFUser(fromFirestore: data, id: id)
    }

    func clearMessages() {
        error = nil
        successMessage = nil
    }
}
