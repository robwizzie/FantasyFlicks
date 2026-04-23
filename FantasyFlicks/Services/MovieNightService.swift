//
//  MovieNightService.swift
//  FantasyFlicks
//
//  Firestore service for Movie Night sessions
//

import Foundation
import FirebaseFirestore

/// Manages Movie Night session data in Firestore
@MainActor
final class MovieNightService {

    // MARK: - Singleton

    static let shared = MovieNightService()

    // MARK: - Properties

    private let db = Firestore.firestore()
    private let authService = AuthenticationService.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Session CRUD

    /// Create a new Movie Night session
    func createSession(filters: MovieNightFilters) async throws -> MovieNightSession {
        guard let user = authService.currentUser else {
            throw MovieNightError.notAuthenticated
        }

        let sessionId = UUID().uuidString
        let hostSeenIds = Array(SeenMoviesService.shared.seenTmdbIds)
        let session = MovieNightSession(
            id: sessionId,
            hostId: user.id,
            participantIds: [user.id],
            inviteCode: MovieNightSession.generateInviteCode(),
            status: .lobby,
            deckTmdbIds: [],
            filters: filters,
            participantNames: [user.id: user.displayName.isEmpty ? user.username : user.displayName],
            participantSeenIds: [user.id: hostSeenIds],
            createdAt: Date(),
            completedAt: nil
        )

        try db.collection("movieNightSessions").document(sessionId).setData(from: session)
        return session
    }

    /// Upload the current user's seen movie IDs to the session (for party-wide exclusion)
    func uploadSeenIds(sessionId: String, seenIds: [Int]) async throws {
        guard let userId = authService.currentUser?.id else {
            throw MovieNightError.notAuthenticated
        }
        try await db.collection("movieNightSessions").document(sessionId).updateData([
            "participantSeenIds.\(userId)": seenIds
        ])
    }

    /// Join an existing session by invite code
    func joinSession(inviteCode: String) async throws -> MovieNightSession {
        guard let user = authService.currentUser else {
            throw MovieNightError.notAuthenticated
        }

        let snapshot = try await db.collection("movieNightSessions")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .whereField("status", isEqualTo: MovieNightStatus.lobby.rawValue)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            throw MovieNightError.sessionNotFound
        }

        var session = try document.data(as: MovieNightSession.self)

        guard !session.participantIds.contains(user.id) else {
            return session // Already in the session
        }

        guard !session.isExpired else {
            throw MovieNightError.sessionExpired
        }

        // Add participant
        let displayName = user.displayName.isEmpty ? user.username : user.displayName
        let userSeenIds = Array(SeenMoviesService.shared.seenTmdbIds)
        session.participantIds.append(user.id)
        session.participantNames[user.id] = displayName
        if session.participantSeenIds == nil { session.participantSeenIds = [:] }
        session.participantSeenIds?[user.id] = userSeenIds

        try await db.collection("movieNightSessions").document(session.id).updateData([
            "participantIds": FieldValue.arrayUnion([user.id]),
            "participantNames.\(user.id)": displayName,
            "participantSeenIds.\(user.id)": userSeenIds
        ])

        return session
    }

    /// Update session filters (host only, while still in lobby)
    func updateFilters(sessionId: String, filters: MovieNightFilters) async throws {
        let data = try Firestore.Encoder().encode(filters)
        try await db.collection("movieNightSessions").document(sessionId).updateData([
            "filters": data
        ])
    }

    /// Start swiping phase — writes deck to session and transitions status
    func startSession(sessionId: String, deckTmdbIds: [Int]) async throws {
        try await db.collection("movieNightSessions").document(sessionId).updateData([
            "status": MovieNightStatus.swiping.rawValue,
            "deckTmdbIds": deckTmdbIds
        ])
    }

    /// Submit a swipe
    func submitSwipe(sessionId: String, tmdbId: Int, wantToWatch: Bool, hasSeenIt: Bool) async throws {
        guard let userId = authService.currentUser?.id else {
            throw MovieNightError.notAuthenticated
        }

        let swipeId = "\(userId)_\(tmdbId)"
        let swipe = MovieNightSwipe(
            id: swipeId,
            sessionId: sessionId,
            userId: userId,
            tmdbId: tmdbId,
            wantToWatch: wantToWatch,
            hasSeenIt: hasSeenIt,
            swipedAt: Date()
        )

        try db.collection("movieNightSessions").document(sessionId)
            .collection("swipes").document(swipeId).setData(from: swipe)
    }

    /// Delete a swipe (for undo)
    func deleteSwipe(sessionId: String, tmdbId: Int) async throws {
        guard let userId = authService.currentUser?.id else {
            throw MovieNightError.notAuthenticated
        }

        let swipeId = "\(userId)_\(tmdbId)"
        try await db.collection("movieNightSessions").document(sessionId)
            .collection("swipes").document(swipeId).delete()
    }

    /// Mark session as complete with results
    func completeSession(sessionId: String) async throws {
        try await db.collection("movieNightSessions").document(sessionId).updateData([
            "status": MovieNightStatus.results.rawValue,
            "completedAt": Timestamp(date: Date())
        ])
    }

    /// Leave a session (remove from participants)
    func leaveSession(sessionId: String) async throws {
        guard let userId = authService.currentUser?.id else {
            throw MovieNightError.notAuthenticated
        }

        try await db.collection("movieNightSessions").document(sessionId).updateData([
            "participantIds": FieldValue.arrayRemove([userId]),
            "participantNames.\(userId)": FieldValue.delete()
        ])
    }

    /// Delete a session (host only) or remove self from it
    func deleteSession(sessionId: String) async throws {
        guard let userId = authService.currentUser?.id else {
            throw MovieNightError.notAuthenticated
        }

        let docRef = db.collection("movieNightSessions").document(sessionId)
        let snapshot = try await docRef.getDocument()
        guard let session = try? snapshot.data(as: MovieNightSession.self) else { return }

        if session.hostId == userId {
            // Host: delete the entire session document
            try await docRef.delete()
        } else {
            // Non-host: just remove self from participants
            try await leaveSession(sessionId: sessionId)
        }
    }

    // MARK: - Queries

    /// Fetch user's active sessions
    func getUserSessions() async throws -> [MovieNightSession] {
        guard let userId = authService.currentUser?.id else {
            throw MovieNightError.notAuthenticated
        }

        let snapshot = try await db.collection("movieNightSessions")
            .whereField("participantIds", arrayContains: userId)
            .limit(to: 20)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: MovieNightSession.self) }
            .filter { !$0.isExpired || $0.status == .results }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Real-Time Listeners

    /// Listen to session document changes
    func listenToSession(sessionId: String, onChange: @escaping (MovieNightSession?) -> Void) -> ListenerRegistration {
        db.collection("movieNightSessions").document(sessionId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot, error == nil else {
                    onChange(nil)
                    return
                }
                let session = try? snapshot.data(as: MovieNightSession.self)
                Task { @MainActor in
                    onChange(session)
                }
            }
    }

    /// Listen to all swipes in a session
    func listenToSwipes(sessionId: String, onChange: @escaping ([MovieNightSwipe]) -> Void) -> ListenerRegistration {
        db.collection("movieNightSessions").document(sessionId)
            .collection("swipes")
            .addSnapshotListener { snapshot, error in
                guard let snapshot, error == nil else {
                    onChange([])
                    return
                }
                let swipes = snapshot.documents.compactMap { try? $0.data(as: MovieNightSwipe.self) }
                Task { @MainActor in
                    onChange(swipes)
                }
            }
    }
}

// MARK: - Errors

enum MovieNightError: LocalizedError {
    case notAuthenticated
    case sessionNotFound
    case sessionExpired
    case notHost
    case alreadySwiping

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to use Movie Night."
        case .sessionNotFound: return "No active session found with that code."
        case .sessionExpired: return "This session has expired."
        case .notHost: return "Only the host can start the session."
        case .alreadySwiping: return "Swiping has already started."
        }
    }
}
