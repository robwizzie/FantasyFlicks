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
import FirebaseCore

/// Manages user authentication state and sign-in methods
@MainActor
final class AuthenticationService: ObservableObject {

    // MARK: - Singleton

    static let shared = AuthenticationService()

    // MARK: - Published Properties

    @Published private(set) var currentUser: FFUser?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published private(set) var hasCompletedProfileSetup = false
    @Published var error: String?

    // MARK: - Private Properties

    private var currentNonce: String?
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Initialization

    private init() {
        configureGoogleSignIn()
        setupAuthStateListener()
    }

    // MARK: - Google Sign In Configuration

    private func configureGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Warning: Firebase client ID not found")
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
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
                    self?.hasCompletedProfileSetup = false
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

        // Verify Google Sign-In is configured
        guard GIDSignIn.sharedInstance.configuration != nil else {
            self.error = "Google Sign-In is not configured. Please ensure GoogleService-Info.plist is added to the project."
            throw AuthError.configurationMissing
        }

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

        } catch let signInError as GIDSignInError {
            // Handle specific Google Sign-In errors
            switch signInError.code {
            case .canceled:
                // User canceled, don't show error
                break
            case .hasNoAuthInKeychain:
                self.error = "No previous sign-in found. Please sign in again."
            default:
                self.error = signInError.localizedDescription
            }
            throw signInError
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
            hasCompletedProfileSetup = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - User Management

    private func fetchOrCreateUser(firebaseUser: User, email: String? = nil) async {
        let userId = firebaseUser.uid

        do {
            // Try to get from server first, fall back to cache if offline
            let document: DocumentSnapshot
            do {
                document = try await db.collection("users").document(userId).getDocument(source: .server)
            } catch {
                // If server fails (offline), try cache
                document = try await db.collection("users").document(userId).getDocument(source: .cache)
            }

            if document.exists, let data = document.data() {
                // User exists, decode it - extract values first to help compiler
                let username = data["username"] as? String ?? firebaseUser.displayName ?? "User"
                let displayName = data["displayName"] as? String ?? firebaseUser.displayName ?? "User"
                let userEmail = data["email"] as? String ?? firebaseUser.email ?? ""
                let avatarURLString = data["avatarURL"] as? String
                let avatarURL = avatarURLString.flatMap { URL(string: $0) }
                let profileSetupComplete = data["hasCompletedProfileSetup"] as? Bool ?? false

                currentUser = FFUser(
                    id: userId,
                    username: username,
                    displayName: displayName,
                    email: userEmail,
                    avatarURL: avatarURL,
                    avatarIcon: data["avatarIcon"] as? String,
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
                    hasCompletedProfileSetup: profileSetupComplete,
                    favoriteGenre: data["favoriteGenre"] as? String,
                    bio: data["bio"] as? String
                )
                isAuthenticated = true
                hasCompletedProfileSetup = profileSetupComplete
            } else {
                // Create new user - requires network
                await createNewUser(firebaseUser: firebaseUser, email: email)
            }

        } catch {
            // If both server and cache fail, create a local-only user for new sign-ups
            // or show error for existing users
            if firebaseUser.metadata.creationDate == firebaseUser.metadata.lastSignInDate {
                // New user - create locally and sync later
                await createNewUser(firebaseUser: firebaseUser, email: email)
            } else {
                self.error = "Unable to load user data. Please check your connection and try again."
            }
        }
    }

    private func createNewUser(firebaseUser: User, email: String?) async {
        let userId = firebaseUser.uid
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
            blockedUserIds: [],
            hasCompletedProfileSetup: false,
            favoriteGenre: nil,
            bio: nil
        )

        // Try to save to Firestore (will queue if offline)
        do {
            try await db.collection("users").document(userId).setData([
                "username": newUser.username,
                "usernameLowercase": newUser.username.lowercased(),
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
                "hasCompletedProfileSetup": false,
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch {
            // Firestore will sync when back online
            print("User data will sync when online: \(error.localizedDescription)")
        }

        currentUser = newUser
        isAuthenticated = true
        hasCompletedProfileSetup = false
    }

    // MARK: - Username Validation

    /// Reserved usernames that cannot be used
    private static let reservedUsernames: Set<String> = [
        "admin", "administrator", "support", "help", "moderator", "mod",
        "fantasyflicks", "fantasy_flicks", "official", "system", "root",
        "null", "undefined", "anonymous", "user", "guest"
    ]

    /// Check if a username is available (case-insensitive)
    func checkUsernameAvailability(_ username: String) async -> Bool {
        let lowercasedUsername = username.lowercased()

        // Check reserved usernames
        if Self.reservedUsernames.contains(lowercasedUsername) {
            return false
        }

        do {
            let snapshot = try await db.collection("users")
                .whereField("usernameLowercase", isEqualTo: lowercasedUsername)
                .limit(to: 1)
                .getDocuments()

            return snapshot.documents.isEmpty
        } catch {
            print("Error checking username availability: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Profile Update

    /// Update user profile after initial setup
    func updateUserProfile(
        displayName: String,
        username: String,
        avatarURL: URL?,
        avatarIcon: String?,
        favoriteGenre: String?,
        bio: String?
    ) async throws {
        guard let userId = currentUser?.id else {
            throw AuthError.userNotFound
        }

        let updateData: [String: Any] = [
            "displayName": displayName,
            "username": username,
            "usernameLowercase": username.lowercased(),
            "avatarURL": avatarURL?.absoluteString as Any,
            "avatarIcon": avatarIcon as Any,
            "favoriteGenre": favoriteGenre as Any,
            "bio": bio as Any,
            "hasCompletedProfileSetup": true
        ]

        try await db.collection("users").document(userId).updateData(updateData)

        // Update local user
        if var user = currentUser {
            user.displayName = displayName
            user.username = username
            user.avatarURL = avatarURL
            user.avatarIcon = avatarIcon
            user.favoriteGenre = favoriteGenre
            user.bio = bio
            user.hasCompletedProfileSetup = true
            currentUser = user
        }

        hasCompletedProfileSetup = true
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
    case configurationMissing

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
        case .configurationMissing:
            return "Authentication is not properly configured. Please contact support."
        }
    }
}
