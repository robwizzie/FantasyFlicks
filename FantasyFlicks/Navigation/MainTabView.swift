//
//  MainTabView.swift
//  FantasyFlicks
//
//  Main tab bar navigation for the app
//

import SwiftUI

/// Main tab-based navigation container
struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @Namespace private var animation

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(Tab.home)

                LeaguesView()
                    .tag(Tab.leagues)

                DraftView()
                    .tag(Tab.draft)

                MoviesView()
                    .tag(Tab.movies)

                ProfileView()
                    .tag(Tab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab, animation: animation)
        }
        .ignoresSafeArea(.keyboard)
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

    var selectedIcon: String {
        icon // Using same icon, could be different if desired
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    var animation: Namespace.ID

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    animation: animation
                ) {
                    withAnimation(FFAnimations.snappy) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, FFSpacing.md)
        .padding(.top, FFSpacing.md)
        .padding(.bottom, FFSpacing.xl)
        .background {
            // Glass background
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    FFColors.backgroundElevated.opacity(0.9),
                                    FFColors.backgroundDark.opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(FFColors.goldPrimary.opacity(0.3))
                        .frame(height: 0.5)
                }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let tab: Tab
    let isSelected: Bool
    var animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FFSpacing.xs) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .fill(FFColors.goldGradient)
                            .frame(width: 56, height: 32)
                            .matchedGeometryEffect(id: "TAB_HIGHLIGHT", in: animation)
                    }

                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textSecondary)
                        .frame(width: 56, height: 32)
                }

                Text(tab.rawValue)
                    .font(FFTypography.caption)
                    .foregroundColor(isSelected ? FFColors.goldPrimary : FFColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .ffTheme()
}
