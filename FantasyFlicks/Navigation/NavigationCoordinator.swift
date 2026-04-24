//
//  NavigationCoordinator.swift
//  FantasyFlicks
//
//  Centralized navigation state management for the app
//

import SwiftUI
import Combine

/// Observable navigation coordinator for managing app-wide navigation state
@MainActor
final class NavigationCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = NavigationCoordinator()

    // MARK: - Published Properties

    /// Currently selected tab
    @Published var selectedTab: Tab = .home

    /// Session ID to auto-resume when Movie Night tab opens
    @Published var pendingResumeSessionId: String?

    /// Retained for compatibility with the archived Leagues feature; not currently exposed in navigation.
    @Published var showCreateLeague = false
    @Published var showJoinLeague = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Navigation Methods

    /// Navigate to a specific tab
    func navigateTo(_ tab: Tab) {
        withAnimation(FFAnimations.snappy) {
            selectedTab = tab
        }
    }

    /// Navigate to the Movie Night tab
    func showMovieNightFlow() {
        navigateTo(.movieNights)
    }

    /// Navigate to Movie Night tab and auto-resume a specific session
    func resumeMovieNightSession(_ sessionId: String) {
        pendingResumeSessionId = sessionId
        navigateTo(.movieNights)
    }

    /// Navigate to the Friends tab
    func showFriendsFlow() {
        navigateTo(.friends)
    }
}

// MARK: - Environment Key

private struct NavigationCoordinatorKey: EnvironmentKey {
    static let defaultValue = NavigationCoordinator.shared
}

extension EnvironmentValues {
    var navigationCoordinator: NavigationCoordinator {
        get { self[NavigationCoordinatorKey.self] }
        set { self[NavigationCoordinatorKey.self] = newValue }
    }
}
