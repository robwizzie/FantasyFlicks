//
//  MainTabView.swift
//  FantasyFlicks
//
//  Main tab bar navigation using native iOS TabView with liquid glass effect
//

import SwiftUI

/// Main tab-based navigation container using native iOS tab bar
struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            LeaguesView()
                .tabItem {
                    Label(Tab.leagues.rawValue, systemImage: Tab.leagues.icon)
                }
                .tag(Tab.leagues)

            DraftView()
                .tabItem {
                    Label(Tab.draft.rawValue, systemImage: Tab.draft.icon)
                }
                .tag(Tab.draft)

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
    }
}

// MARK: - Tab Enum

enum Tab: String, CaseIterable {
    case home = "Home"
    case leagues = "Leagues"
    case draft = "Draft"
    case movies = "Movies"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .leagues: return "trophy.fill"
        case .draft: return "list.clipboard.fill"
        case .movies: return "film.fill"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .ffTheme()
}
