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

            ComingSoonTabView(
                title: "Leagues",
                icon: "trophy.fill",
                tagline: "Fantasy leagues are coming soon",
                description: "Draft movies, compete with friends, and win based on box office. We're focused on Movie Night for now."
            )
            .tabItem {
                Label(Tab.leagues.rawValue, systemImage: Tab.leagues.icon)
            }
            .tag(Tab.leagues)

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
    case leagues = "Leagues"
    case movies = "Movies"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .movieNights: return "popcorn.fill"
        case .leagues: return "trophy.fill"
        case .movies: return "film.fill"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Coming Soon Tab

struct ComingSoonTabView: View {
    let title: String
    let icon: String
    let tagline: String
    let description: String

    @ObservedObject private var nav = NavigationCoordinator.shared

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                VStack(spacing: FFSpacing.xxl) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(FFColors.goldPrimary.opacity(0.15))
                            .frame(width: 160, height: 160)
                            .blur(radius: 40)

                        Image(systemName: icon)
                            .font(.system(size: 72))
                            .foregroundStyle(FFColors.goldGradient)
                    }

                    VStack(spacing: FFSpacing.md) {
                        Badge(text: "Coming Soon", style: .gold)

                        Text(tagline)
                            .font(FFTypography.displaySmall)
                            .foregroundColor(FFColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, FFSpacing.lg)

                        Text(description)
                            .font(FFTypography.bodyMedium)
                            .foregroundColor(FFColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, FFSpacing.xxl)
                    }

                    GoldButton(
                        title: "Host Movie Night",
                        icon: "popcorn.fill",
                        style: .primary,
                        size: .large
                    ) {
                        nav.navigateTo(.movieNights)
                    }
                    .padding(.horizontal, FFSpacing.xxl)

                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MainTabView()
        .ffTheme()
}
