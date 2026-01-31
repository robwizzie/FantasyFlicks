//
//  ProfileView.swift
//  FantasyFlicks
//
//  Profile tab - user profile and settings
//

import SwiftUI

struct ProfileView: View {
    @State private var showSettings = false
    @State private var showEditProfile = false

    private let user = FFUser.sample

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: FFSpacing.xl) {
                        // Profile header
                        profileHeader

                        // Stats
                        statsSection

                        // Achievements
                        achievementsSection

                        // Recent activity
                        recentActivitySection

                        // Settings links
                        settingsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
        }
    }

    private var profileHeader: some View {
        GlassCard(goldTint: true) {
            HStack(spacing: FFSpacing.lg) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(FFColors.goldGradient)
                        .frame(width: 80, height: 80)

                    Text(user.displayName.prefix(1).uppercased())
                        .font(FFTypography.displayMedium)
                        .foregroundColor(FFColors.backgroundDark)
                }

                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text(user.displayName)
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.textPrimary)

                    Text("@\(user.username)")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)

                    HStack(spacing: FFSpacing.sm) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(FFColors.goldPrimary)

                        Text("\(user.rankingPoints) points")
                            .font(FFTypography.labelSmall)
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }

                Spacer()

                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FFColors.goldPrimary)
                        .frame(width: 36, height: 36)
                        .background(FFColors.goldPrimary.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Stats")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            HStack(spacing: FFSpacing.md) {
                StatCard(value: "\(user.totalLeagues)", label: "Leagues", icon: "trophy.fill")
                StatCard(value: "\(user.leaguesWon)", label: "Wins", icon: "crown.fill")
                StatCard(value: user.winRatePercentage, label: "Win Rate", icon: "chart.line.uptrend.xyaxis")
                StatCard(value: "\(user.totalMoviesDrafted)", label: "Drafted", icon: "film.fill")
            }
            .padding(.horizontal)
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Achievements")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                Button {
                    // View all achievements
                } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(FFTypography.labelSmall)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(FFColors.goldPrimary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FFSpacing.md) {
                    AchievementBadge(icon: "star.fill", name: "First Draft", isUnlocked: true)
                    AchievementBadge(icon: "flame.fill", name: "Hot Streak", isUnlocked: true)
                    AchievementBadge(icon: "crown.fill", name: "Champion", isUnlocked: false)
                    AchievementBadge(icon: "eye.fill", name: "Prophet", isUnlocked: false)
                }
                .padding(.horizontal)
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Recent Activity")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            VStack(spacing: FFSpacing.sm) {
                ActivityRow(
                    icon: "trophy.fill",
                    text: "Joined Box Office Champions",
                    time: "2 days ago"
                )
                ActivityRow(
                    icon: "film.fill",
                    text: "Drafted Avatar 4",
                    time: "2 days ago"
                )
                ActivityRow(
                    icon: "star.fill",
                    text: "Earned 'First Draft' achievement",
                    time: "2 days ago"
                )
            }
            .padding(.horizontal)
        }
    }

    private var settingsSection: some View {
        VStack(spacing: FFSpacing.sm) {
            SettingsRow(icon: "bell.fill", title: "Notifications")
            SettingsRow(icon: "person.2.fill", title: "Friends")
            SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support")
            SettingsRow(icon: "info.circle.fill", title: "About")
        }
        .padding(.horizontal)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: FFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(FFColors.goldGradient)

            Text(value)
                .font(FFTypography.titleMedium)
                .foregroundColor(FFColors.textPrimary)

            Text(label)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FFSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.backgroundElevated.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let icon: String
    let name: String
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: FFSpacing.sm) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? FFColors.goldGradient : LinearGradient(colors: [FFColors.backgroundElevated, FFColors.backgroundElevated], startPoint: .top, endPoint: .bottom))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isUnlocked ? FFColors.backgroundDark : FFColors.textTertiary)
            }
            .opacity(isUnlocked ? 1 : 0.5)

            Text(name)
                .font(FFTypography.caption)
                .foregroundColor(isUnlocked ? FFColors.textPrimary : FFColors.textTertiary)
        }
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let icon: String
    let text: String
    let time: String

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            ZStack {
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(FFColors.goldPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textPrimary)

                Text(time)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }

            Spacer()
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated.opacity(0.4))
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        Button {
            // Navigate
        } label: {
            HStack(spacing: FFSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(FFColors.goldPrimary)
                    .frame(width: 24)

                Text(title)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(FFColors.textTertiary)
            }
            .padding(FFSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(FFColors.backgroundElevated.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                List {
                    Section("Account") {
                        SettingsListRow(icon: "person.fill", title: "Edit Profile")
                        SettingsListRow(icon: "envelope.fill", title: "Email")
                        SettingsListRow(icon: "lock.fill", title: "Password")
                    }

                    Section("Preferences") {
                        SettingsListRow(icon: "bell.fill", title: "Notifications")
                        SettingsListRow(icon: "paintbrush.fill", title: "Appearance")
                    }

                    Section("Support") {
                        SettingsListRow(icon: "questionmark.circle.fill", title: "Help Center")
                        SettingsListRow(icon: "envelope.fill", title: "Contact Us")
                        SettingsListRow(icon: "star.fill", title: "Rate the App")
                    }

                    Section {
                        Button {
                            // Sign out
                        } label: {
                            Text("Sign Out")
                                .foregroundColor(FFColors.ruby)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
    }
}

struct SettingsListRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(FFColors.goldPrimary)
            Text(title)
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .ffTheme()
}
