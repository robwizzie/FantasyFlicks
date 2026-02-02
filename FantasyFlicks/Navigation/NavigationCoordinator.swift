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

    /// Whether to show create league flow
    @Published var showCreateLeague = false

    /// Whether to show join league sheet
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

    /// Navigate to leagues tab and show create league
    func showCreateLeagueFlow() {
        selectedTab = .leagues
        // Small delay to let the tab switch complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showCreateLeague = true
        }
    }

    /// Navigate to leagues tab and show join league
    func showJoinLeagueFlow() {
        selectedTab = .leagues
        // Small delay to let the tab switch complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showJoinLeague = true
        }
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
