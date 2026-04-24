//
//  MainTabView.swift
//  FantasyFlicks
//
//  Main tab bar navigation - Movie Night is the forefront
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared

    var body: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            MovieNightEntryView()
                .tabItem {
                    Label(Tab.movieNights.rawValue, systemImage: Tab.movieNights.icon)
                }
                .tag(Tab.movieNights)

            FriendsTabView()
                .tabItem {
                    Label(Tab.friends.rawValue, systemImage: Tab.friends.icon)
                }
                .tag(Tab.friends)

            MoviesView()
                .tabItem {
                    Label(Tab.movies.rawValue, systemImage: Tab.movies.icon)
                }
                .tag(Tab.movies)

            ProfileView()
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(FFColors.goldPrimary)
        .environment(\.navigationCoordinator, navigationCoordinator)
    }
}

// MARK: - Tab Enum

enum Tab: String, CaseIterable {
    case home = "Home"
    case movieNights = "Nights"
    case friends = "Friends"
    case movies = "Movies"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .movieNights: return "popcorn.fill"
        case .friends: return "person.2.fill"
        case .movies: return "film.fill"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Friends Tab Wrapper
// Reuses FriendsView but without the sheet-dismiss toolbar button, so it can live in a tab.

struct FriendsTabView: View {
    var body: some View {
        FriendsView(isEmbeddedInTab: true)
    }
}

#Preview {
    MainTabView()
        .ffTheme()
}
