//
//  MovieReviewsService.swift
//  FantasyFlicks
//
//  Fetches reviews for a specific movie from friends and/or all public profiles.
//  Reviews come from the diary entries stored in each user's Firestore
//  `mediaDiaryJSON` field — we fan out across users to find ones for a given movie.
//

import Foundation
import FirebaseFirestore

struct MovieReviewItem: Identifiable, Hashable {
    let id: String           // "{userId}_{diaryEntryId}"
    let userId: String
    let userName: String
    let userAvatarURL: URL?
    let userAvatarIcon: String?
    let watchedDate: Date
    let rating: Double?
    let reviewText: String
    let isRewatch: Bool
}

@MainActor
final class MovieReviewsService {

    static let shared = MovieReviewsService()

    private let db = Firestore.firestore()
    private let authService = AuthenticationService.shared

    private init() {}

    /// Fetch reviews for a movie from the user's friends only.
    func friendReviews(for tmdbId: Int) async -> [MovieReviewItem] {
        guard let currentUserId = authService.currentUser?.id else { return [] }

        do {
            let snapshot = try await db.collection("users")
                .document(currentUserId)
                .getDocument()

            guard let data = snapshot.data(),
                  let friendIds = data["friendIds"] as? [String],
                  !friendIds.isEmpty else {
                return []
            }

            return await fetchReviews(for: tmdbId, fromUserIds: friendIds, requirePublic: false)
        } catch {
            return []
        }
    }

    /// Fetch reviews for a movie from all users whose diary is not marked private.
    /// Capped to 50 to keep the query bounded.
    func publicReviews(for tmdbId: Int, limit: Int = 50) async -> [MovieReviewItem] {
        do {
            // Query users whose diary is not private. We still have to iterate
            // to find the ones who actually have a diary entry for this tmdbId.
            let snapshot = try await db.collection("users")
                .whereField("diaryPrivate", isEqualTo: false)
                .limit(to: limit)
                .getDocuments()

            let userIds = snapshot.documents.map { $0.documentID }
            return await fetchReviews(for: tmdbId, fromUserIds: userIds, requirePublic: true)
        } catch {
            return []
        }
    }

    // MARK: - Private

    private func fetchReviews(
        for tmdbId: Int,
        fromUserIds userIds: [String],
        requirePublic: Bool
    ) async -> [MovieReviewItem] {
        // Firestore `in` queries cap at 30 per call — chunk up the list.
        let chunks = userIds.chunked(into: 30)
        var collected: [MovieReviewItem] = []

        for chunk in chunks {
            do {
                let snap = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                for doc in snap.documents {
                    let data = doc.data()
                    if requirePublic && (data["diaryPrivate"] as? Bool ?? false) { continue }

                    guard let diaryJSON = data["mediaDiaryJSON"] as? String,
                          let diaryData = diaryJSON.data(using: .utf8),
                          let entries = try? JSONDecoder().decode([DiaryEntry].self, from: diaryData)
                    else { continue }

                    let matching = entries.filter {
                        $0.tmdbId == tmdbId && ($0.reviewText?.isEmpty == false || $0.effectiveRating != nil)
                    }
                    guard !matching.isEmpty else { continue }

                    let username = (data["displayName"] as? String)
                        ?? (data["username"] as? String)
                        ?? "Friend"
                    let avatarURL: URL? = (data["avatarURL"] as? String).flatMap { URL(string: $0) }
                    let avatarIcon = data["avatarIcon"] as? String

                    for entry in matching {
                        collected.append(MovieReviewItem(
                            id: "\(doc.documentID)_\(entry.id)",
                            userId: doc.documentID,
                            userName: username,
                            userAvatarURL: avatarURL,
                            userAvatarIcon: avatarIcon,
                            watchedDate: entry.watchedDate,
                            rating: entry.effectiveRating,
                            reviewText: entry.reviewText ?? "",
                            isRewatch: entry.isRewatch
                        ))
                    }
                }
            } catch {
                continue
            }
        }

        // Newest first
        return collected.sorted { $0.watchedDate > $1.watchedDate }
    }
}

// MARK: - Array chunking (needed because Firestore `in` queries cap at 30)

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
