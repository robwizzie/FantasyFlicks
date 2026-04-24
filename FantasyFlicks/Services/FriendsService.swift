//
//  FriendsService.swift
//  FantasyFlicks
//
//  Manages the user's one-way friend list: search, add, remove, block, hydrate.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class FriendsService: ObservableObject {

    // MARK: - Singleton

    static let shared = FriendsService()

    // MARK: - Published

    @Published private(set) var friends: [FFUser] = []
    @Published private(set) var isLoading = false
    @Published var error: String?

    // MARK: - Private

    private let db = Firestore.firestore()
    private let authService = AuthenticationService.shared

    private init() {}

    // MARK: - Search

    /// Prefix-search users by username (case-insensitive).
    /// Filters out the current user and anyone the current user has blocked.
    func searchUsers(query: String, limit: Int = 20) async throws -> [FFUser] {
        let trimmed = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let snapshot = try await db.collection("users")
            .whereField("usernameLowercase", isGreaterThanOrEqualTo: trimmed)
            .whereField("usernameLowercase", isLessThanOrEqualTo: trimmed + "\u{f8ff}")
            .limit(to: limit)
            .getDocuments()

        let currentUserId = authService.currentUser?.id
        let blocked = Set(authService.currentUser?.blockedUserIds ?? [])

        return snapshot.documents
            .map { FFUser(fromFirestore: $0.data(), id: $0.documentID) }
            .filter { $0.id != currentUserId && !blocked.contains($0.id) }
    }

    // MARK: - Fetch

    func fetchUser(id: String) async throws -> FFUser {
        let doc = try await db.collection("users").document(id).getDocument()
        guard let data = doc.data() else {
            throw FriendsError.userNotFound
        }
        return FFUser(fromFirestore: data, id: doc.documentID)
    }

    /// Refresh the friend list by hydrating user docs for the current user's friendIds.
    /// Chunks the query to respect Firestore's 30-ID limit on `in` queries.
    func refreshFriendList() async {
        guard let currentUser = authService.currentUser else { return }
        let friendIds = currentUser.friendIds
        guard !friendIds.isEmpty else {
            friends = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        var hydrated: [FFUser] = []
        do {
            for chunk in friendIds.chunked(into: 30) {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                hydrated.append(contentsOf: snapshot.documents.map {
                    FFUser(fromFirestore: $0.data(), id: $0.documentID)
                })
            }
            // Preserve order roughly by displayName for stability
            friends = hydrated.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Mutations

    func addFriend(_ friend: FFUser) async throws {
        guard let currentUserId = authService.currentUser?.id else {
            throw FriendsError.notAuthenticated
        }
        guard friend.id != currentUserId else { return }

        try await db.collection("users").document(currentUserId).updateData([
            "friendIds": FieldValue.arrayUnion([friend.id])
        ])

        if !friends.contains(where: { $0.id == friend.id }) {
            friends.append(friend)
            friends.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            AchievementService.shared.evaluateUnlocks(friendCount: friends.count)
        }
    }

    func removeFriend(userId: String) async throws {
        guard let currentUserId = authService.currentUser?.id else {
            throw FriendsError.notAuthenticated
        }

        try await db.collection("users").document(currentUserId).updateData([
            "friendIds": FieldValue.arrayRemove([userId])
        ])

        friends.removeAll { $0.id == userId }
    }

    func blockUser(_ userId: String) async throws {
        guard let currentUserId = authService.currentUser?.id else {
            throw FriendsError.notAuthenticated
        }

        try await db.collection("users").document(currentUserId).updateData([
            "blockedUserIds": FieldValue.arrayUnion([userId]),
            "friendIds": FieldValue.arrayRemove([userId])
        ])

        friends.removeAll { $0.id == userId }
    }

    // MARK: - Queries

    func isFriend(_ userId: String) -> Bool {
        friends.contains { $0.id == userId }
            || (authService.currentUser?.friendIds.contains(userId) ?? false)
    }
}

// MARK: - Errors

enum FriendsError: LocalizedError {
    case notAuthenticated
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to manage friends."
        case .userNotFound: return "User not found."
        }
    }
}

// MARK: - Array chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
