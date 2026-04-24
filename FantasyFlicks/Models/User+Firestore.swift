//
//  User+Firestore.swift
//  FantasyFlicks
//
//  Shared FFUser parsing from a Firestore document dictionary.
//  Used by ProfileViewModel, FriendsService, and AuthenticationService
//  to guarantee a single source of truth for user-doc decoding.
//

import Foundation
import FirebaseFirestore

extension FFUser {
    init(fromFirestore data: [String: Any], id: String) {
        let createdAt: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else {
            createdAt = Date()
        }

        let lastActiveAt: Date
        if let ts = data["lastActiveAt"] as? Timestamp {
            lastActiveAt = ts.dateValue()
        } else {
            lastActiveAt = Date()
        }

        self.init(
            id: id,
            username: data["username"] as? String ?? "user",
            displayName: data["displayName"] as? String ?? "User",
            email: data["email"] as? String ?? "",
            avatarURL: (data["avatarURL"] as? String).flatMap { URL(string: $0) },
            avatarIcon: data["avatarIcon"] as? String,
            avatarBase64: data["avatarBase64"] as? String,
            totalLeagues: data["totalLeagues"] as? Int ?? 0,
            leaguesWon: data["leaguesWon"] as? Int ?? 0,
            totalMoviesDrafted: data["totalMoviesDrafted"] as? Int ?? 0,
            bestMovieScore: data["bestMovieScore"] as? Double,
            rankingPoints: data["rankingPoints"] as? Int ?? 0,
            achievementIds: data["achievementIds"] as? [String] ?? [],
            notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true,
            draftReminderMinutes: data["draftReminderMinutes"] as? Int ?? 30,
            friendIds: data["friendIds"] as? [String] ?? [],
            blockedUserIds: data["blockedUserIds"] as? [String] ?? [],
            hasCompletedProfileSetup: data["hasCompletedProfileSetup"] as? Bool ?? false,
            favoriteGenre: data["favoriteGenre"] as? String,
            bio: data["bio"] as? String,
            diaryPrivate: data["diaryPrivate"] as? Bool ?? false,
            watchedPrivate: data["watchedPrivate"] as? Bool ?? false,
            watchlistPrivate: data["watchlistPrivate"] as? Bool ?? false,
            ratingsPrivate: data["ratingsPrivate"] as? Bool ?? false,
            favoriteMovieIds: data["favoriteMovieIds"] as? [Int] ?? [],
            createdAt: createdAt,
            lastActiveAt: lastActiveAt
        )
    }
}
