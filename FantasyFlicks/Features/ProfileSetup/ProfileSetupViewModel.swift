//
//  ProfileSetupViewModel.swift
//  FantasyFlicks
//
//  ViewModel for handling profile setup logic including username validation
//

import Foundation
import SwiftUI
import Combine

/// Represents the current step in the profile setup flow
enum ProfileSetupStep: Int, CaseIterable {
    case nameAndUsername = 0
    case avatar = 1
    case genreAndBio = 2
    case complete = 3

    var title: String {
        switch self {
        case .nameAndUsername: return "Create Your Profile"
        case .avatar: return "Choose Your Avatar"
        case .genreAndBio: return "Tell Us About You"
        case .complete: return "You're All Set!"
        }
    }

    var subtitle: String {
        switch self {
        case .nameAndUsername: return "Pick a display name and unique username"
        case .avatar: return "Select a profile picture"
        case .genreAndBio: return "What movies do you love?"
        case .complete: return "Welcome to Fantasy Flicks"
        }
    }
}

/// Username validation state
enum UsernameValidationState: Equatable {
    case empty
    case checking
    case valid
    case invalid(String)

    var message: String? {
        switch self {
        case .empty: return nil
        case .checking: return "Checking availability..."
        case .valid: return "Username is available!"
        case .invalid(let reason): return reason
        }
    }

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

/// Available movie genres for selection
enum MovieGenre: String, CaseIterable, Identifiable {
    case action = "Action"
    case comedy = "Comedy"
    case drama = "Drama"
    case horror = "Horror"
    case sciFi = "Sci-Fi"
    case romance = "Romance"
    case thriller = "Thriller"
    case animation = "Animation"
    case documentary = "Documentary"
    case fantasy = "Fantasy"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .action: return "flame.fill"
        case .comedy: return "face.smiling.fill"
        case .drama: return "theatermasks.fill"
        case .horror: return "moon.fill"
        case .sciFi: return "sparkles"
        case .romance: return "heart.fill"
        case .thriller: return "bolt.fill"
        case .animation: return "paintpalette.fill"
        case .documentary: return "video.fill"
        case .fantasy: return "wand.and.stars"
        }
    }
}

/// Default avatar options using SF Symbols
enum DefaultAvatar: String, CaseIterable, Identifiable {
    case film = "film.fill"
    case star = "star.fill"
    case trophy = "trophy.fill"
    case ticket = "ticket.fill"
    case tv = "tv.fill"
    case camera = "camera.fill"
    case sparkles = "sparkles"
    case person = "person.crop.circle.fill"

    var id: String { rawValue }
}

@MainActor
final class ProfileSetupViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentStep: ProfileSetupStep = .nameAndUsername
    @Published var displayName: String = ""
    @Published var username: String = ""
    @Published var usernameValidationState: UsernameValidationState = .empty
    @Published var selectedDefaultAvatar: DefaultAvatar?
    @Published var selectedGenre: MovieGenre?
    @Published var bio: String = ""
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Private Properties

    private let authService = AuthenticationService.shared
    private var usernameCheckTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var canProceedFromStep1: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        usernameValidationState.isValid
    }

    var canProceedFromStep2: Bool {
        selectedDefaultAvatar != nil
    }

    var canProceedFromStep3: Bool {
        // Genre is optional, so always allow proceeding
        true
    }

    var totalSteps: Int {
        ProfileSetupStep.allCases.count - 1 // Exclude complete step from count
    }

    // MARK: - Username Validation

    func validateUsername(_ input: String) {
        // Cancel any pending validation
        usernameCheckTask?.cancel()

        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Empty check
        guard !trimmed.isEmpty else {
            usernameValidationState = .empty
            return
        }

        // Length check (3-30 characters)
        guard trimmed.count >= 3 else {
            usernameValidationState = .invalid("Username must be at least 3 characters")
            return
        }

        guard trimmed.count <= 30 else {
            usernameValidationState = .invalid("Username must be 30 characters or less")
            return
        }

        // Character check (alphanumeric + underscores only)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            usernameValidationState = .invalid("Only letters, numbers, and underscores allowed")
            return
        }

        // Debounced availability check
        usernameValidationState = .checking

        usernameCheckTask = Task {
            // Debounce for 500ms
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            let isAvailable = await authService.checkUsernameAvailability(trimmed)

            guard !Task.isCancelled else { return }

            if isAvailable {
                usernameValidationState = .valid
            } else {
                usernameValidationState = .invalid("Username is already taken")
            }
        }
    }

    // MARK: - Avatar Selection

    func selectDefaultAvatar(_ avatar: DefaultAvatar) {
        selectedDefaultAvatar = avatar
    }

    // MARK: - Navigation

    func goToNextStep() {
        guard let nextStep = ProfileSetupStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStep = nextStep
        }
    }

    func goToPreviousStep() {
        guard let previousStep = ProfileSetupStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStep = previousStep
        }
    }

    // MARK: - Complete Setup

    func completeSetup() async {
        isLoading = true
        error = nil

        do {
            // Update profile in Firestore
            try await authService.updateUserProfile(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                username: username.trimmingCharacters(in: .whitespaces),
                avatarURL: nil,
                avatarIcon: selectedDefaultAvatar?.rawValue,
                favoriteGenre: selectedGenre?.rawValue,
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            // Move to completion step
            goToNextStep()

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
