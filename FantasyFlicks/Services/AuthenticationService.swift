//
//  AuthenticationService.swift
//  FantasyFlicks
//
//  Handles authentication with Apple Sign In and Google Sign In via Firebase
//

import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

/// Manages user authentication state and sign-in methods
@MainActor
final class AuthenticationService: ObservableObject {

    // MARK: - Singleton

    static let shared = AuthenticationService()

    // MARK: - Published Properties

    @Published private(set) var currentUser: FFUser?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published var error: String?

    // MARK: - Private Properties

    private var currentNonce: String?
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Initialization

    private init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.fetchOrCreateUser(firebaseUser: user)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }

    // MARK: - Apple Sign In

    /// Generates a nonce for Apple Sign In
    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    /// Handle Apple Sign In credential
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        guard let nonce = currentNonce else {
            throw AuthError.invalidNonce
        }

        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidToken
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)

            // Get display name from credential if available
            var displayName = result.user.displayName
            if displayName == nil || displayName?.isEmpty == true {
                if let fullName = credential.fullName {
                    let formatter = PersonNameComponentsFormatter()
                    displayName = formatter.string(from: fullName)
                }
            }

            // Update profile if we have a name
            if let name = displayName, !name.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try? await changeRequest.commitChanges()
            }

            await fetchOrCreateUser(firebaseUser: result.user, email: credential.email)

        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Google Sign In

    /// Handle Google Sign In
    func signInWithGoogle() async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidToken
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            await fetchOrCreateUser(firebaseUser: authResult.user)

        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - User Management

    private func fetchOrCreateUser(firebaseUser: User, email: String? = nil) async {
        let userId = firebaseUser.uid

        do {
            let document = try await db.collection("users").document(userId).getDocument()

            if document.exists, let data = document.data() {
                // User exists, decode it - extract values first to help compiler
                let username = data["username"] as? String ?? firebaseUser.displayName ?? "User"
                let displayName = data["displayName"] as? String ?? firebaseUser.displayName ?? "User"
                let userEmail = data["email"] as? String ?? firebaseUser.email ?? ""
                let avatarURLString = data["avatarURL"] as? String
                let avatarURL = avatarURLString.flatMap { URL(string: $0) }

                currentUser = FFUser(
                    id: userId,
                    username: username,
                    displayName: displayName,
                    email: userEmail,
                    avatarURL: avatarURL,
                    totalLeagues: data["totalLeagues"] as? Int ?? 0,
                    leaguesWon: data["leaguesWon"] as? Int ?? 0,
                    totalMoviesDrafted: data["totalMoviesDrafted"] as? Int ?? 0,
                    bestMovieScore: data["bestMovieScore"] as? Double,
                    rankingPoints: data["rankingPoints"] as? Int ?? 0,
                    achievementIds: data["achievementIds"] as? [String] ?? [],
                    notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true,
                    draftReminderMinutes: data["draftReminderMinutes"] as? Int ?? 30,
                    friendIds: data["friendIds"] as? [String] ?? [],
                    blockedUserIds: data["blockedUserIds"] as? [String] ?? []
                )
            } else {
                // Create new user
                let newUsername = firebaseUser.displayName ?? "User\(String(userId.prefix(4)))"
                let newDisplayName = firebaseUser.displayName ?? "New User"
                let newEmail = email ?? firebaseUser.email ?? ""

                let newUser = FFUser(
                    id: userId,
                    username: newUsername,
                    displayName: newDisplayName,
                    email: newEmail,
                    avatarURL: firebaseUser.photoURL,
                    totalLeagues: 0,
                    leaguesWon: 0,
                    totalMoviesDrafted: 0,
                    bestMovieScore: nil,
                    rankingPoints: 0,
                    achievementIds: [],
                    notificationsEnabled: true,
                    draftReminderMinutes: 30,
                    friendIds: [],
                    blockedUserIds: []
                )

                // Save to Firestore
                try await db.collection("users").document(userId).setData([
                    "username": newUser.username,
                    "displayName": newUser.displayName,
                    "email": newUser.email,
                    "avatarURL": newUser.avatarURL?.absoluteString as Any,
                    "totalLeagues": newUser.totalLeagues,
                    "leaguesWon": newUser.leaguesWon,
                    "totalMoviesDrafted": newUser.totalMoviesDrafted,
                    "rankingPoints": newUser.rankingPoints,
                    "friendIds": newUser.friendIds,
                    "blockedUserIds": newUser.blockedUserIds,
                    "achievementIds": newUser.achievementIds,
                    "notificationsEnabled": newUser.notificationsEnabled,
                    "draftReminderMinutes": newUser.draftReminderMinutes,
                    "createdAt": FieldValue.serverTimestamp()
                ])

                currentUser = newUser
            }

            isAuthenticated = true

        } catch {
            self.error = "Failed to load user data: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper Methods

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidNonce
    case invalidToken
    case noRootViewController
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .invalidNonce:
            return "Invalid authentication nonce. Please try again."
        case .invalidToken:
            return "Invalid authentication token. Please try again."
        case .noRootViewController:
            return "Unable to present sign-in. Please try again."
        case .userNotFound:
            return "User not found. Please sign in again."
        }
    }
}
