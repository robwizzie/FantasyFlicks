//
//  LeagueDashboardView.swift
//  FantasyFlicks
//
//  League dashboard showing standings, scores, and team information
//

import SwiftUI
import FirebaseFirestore

struct LeagueDashboardView: View {
    let league: FFLeague
    @StateObject private var viewModel: LeagueDashboardViewModel
    @State private var selectedTab: DashboardTab = .standings

    enum DashboardTab: String, CaseIterable {
        case standings = "Standings"
        case myTeam = "My Team"
        case teams = "All Teams"
        case scoring = "Scoring"

        var icon: String {
            switch self {
            case .standings: return "list.number"
            case .myTeam: return "person.fill"
            case .teams: return "person.3.fill"
            case .scoring: return "chart.bar.fill"
            }
        }
    }

    init(league: FFLeague) {
        self.league = league
        self._viewModel = StateObject(wrappedValue: LeagueDashboardViewModel(leagueId: league.id, isOscarMode: league.isOscarMode))
    }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Tab selector
                tabSelector

                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    standingsTab
                        .tag(DashboardTab.standings)

                    myTeamTab
                        .tag(DashboardTab.myTeam)

                    allTeamsTab
                        .tag(DashboardTab.teams)

                    scoringTab
                        .tag(DashboardTab.scoring)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle(league.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDashboardData()
        }
        .refreshable {
            await viewModel.loadDashboardData()
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FFSpacing.md) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(FFAnimations.snappy) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, FFSpacing.md)
        }
        .background(FFColors.backgroundElevated.opacity(0.5))
    }

    // MARK: - Standings Tab

    private var standingsTab: some View {
        ScrollView {
            VStack(spacing: FFSpacing.lg) {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(FFColors.goldPrimary)
                        .padding(.top, 100)
                } else if viewModel.standings.isEmpty {
                    emptyStandingsView
                } else {
                    standingsHeader

                    ForEach(Array(viewModel.standings.enumerated()), id: \.element.id) { index, standing in
                        StandingRow(standing: standing, index: index, isOscarMode: league.isOscarMode)
                    }
                }
            }
            .padding()
        }
    }

    private var standingsHeader: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                Text("League Standings")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                if league.draftStatus == .completed {
                    HStack(spacing: FFSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(FFColors.success)
                        Text("Draft Complete - Season in Progress")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.success)
                    }
                }

                if league.isOscarMode, let oscarSettings = league.settings.oscarSettings {
                    VStack(alignment: .leading, spacing: FFSpacing.xs) {
                        Text("Scoring: \(Int(oscarSettings.pointsPerCorrectPick)) point\(oscarSettings.pointsPerCorrectPick == 1 ? "" : "s") per correct pick")
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textSecondary)

                        if let ceremonyDate = oscarSettings.ceremonyDate {
                            HStack(spacing: FFSpacing.xs) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text("Ceremony: \(ceremonyDate, format: .dateTime.month().day().year())")
                            }
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                        }
                    }
                }
            }
        }
    }

    private var emptyStandingsView: some View {
        VStack(spacing: FFSpacing.lg) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(FFColors.textTertiary)

            Text("No Standings Yet")
                .font(FFTypography.headlineMedium)
                .foregroundColor(FFColors.textPrimary)

            Text("Standings will appear once the draft is complete")
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - My Team Tab

    private var myTeamTab: some View {
        ScrollView {
            VStack(spacing: FFSpacing.lg) {
                if let myTeam = viewModel.myTeam {
                    TeamDetailCard(team: myTeam, isOscarMode: league.isOscarMode)
                } else {
                    Text("Loading your team...")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
                        .padding(.top, 100)
                }
            }
            .padding()
        }
    }

    // MARK: - All Teams Tab

    private var allTeamsTab: some View {
        ScrollView {
            VStack(spacing: FFSpacing.md) {
                ForEach(viewModel.standings) { standing in
                    TeamSummaryCard(standing: standing, isOscarMode: league.isOscarMode)
                }
            }
            .padding()
        }
    }

    // MARK: - Scoring Tab

    private var scoringTab: some View {
        ScrollView {
            VStack(spacing: FFSpacing.lg) {
                ScoringInfoCard(league: league)

                if league.isOscarMode {
                    OscarScoringBreakdown(standings: viewModel.standings)
                }
            }
            .padding()
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FFSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(FFTypography.labelMedium)
            }
            .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textSecondary)
            .padding(.horizontal, FFSpacing.lg)
            .padding(.vertical, FFSpacing.sm)
            .background {
                if isSelected {
                    Capsule().fill(FFColors.goldGradientHorizontal)
                } else {
                    Capsule()
                        .fill(FFColors.backgroundElevated)
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Standing Row

struct StandingRow: View {
    let standing: LeagueStanding
    let index: Int
    let isOscarMode: Bool

    var body: some View {
        GlassCard {
            HStack(spacing: FFSpacing.md) {
                // Rank
                ZStack {
                    Circle()
                        .fill(rankColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Text("\(standing.rank)")
                        .font(FFTypography.titleMedium)
                        .foregroundColor(rankColor)
                }

                // Team Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(standing.teamName)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textPrimary)

                    if isOscarMode {
                        Text("\(standing.correctPicks)/\(standing.totalPicks) correct")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textSecondary)
                    } else {
                        Text("Movies: \(standing.movieCount)")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textSecondary)
                    }
                }

                Spacer()

                // Score
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatScore(standing.totalScore))
                        .font(FFTypography.titleMedium)
                        .foregroundColor(FFColors.goldPrimary)

                    Text(isOscarMode ? "points" : "total")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }
            }
        }
    }

    private var rankColor: Color {
        switch standing.rank {
        case 1: return FFColors.goldPrimary
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return FFColors.textSecondary
        }
    }

    private func formatScore(_ score: Double) -> String {
        if isOscarMode {
            return "\(Int(score))"
        } else {
            return formatCurrency(score)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "$%.1fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else {
            return String(format: "$%.0f", value)
        }
    }
}

// MARK: - Team Detail Card

struct TeamDetailCard: View {
    let team: LeagueStanding
    let isOscarMode: Bool

    var body: some View {
        VStack(spacing: FFSpacing.lg) {
            // Team Header
            GlassCard(goldTint: true) {
                VStack(spacing: FFSpacing.md) {
                    Text(team.teamName)
                        .font(FFTypography.displaySmall)
                        .foregroundColor(FFColors.textPrimary)

                    HStack(spacing: FFSpacing.xl) {
                        StatColumn(
                            label: "Rank",
                            value: "#\(team.rank)",
                            icon: "trophy.fill"
                        )

                        Divider()
                            .frame(height: 40)

                        StatColumn(
                            label: isOscarMode ? "Points" : "Total Score",
                            value: formatScore(team.totalScore),
                            icon: "star.fill"
                        )

                        if isOscarMode {
                            Divider()
                                .frame(height: 40)

                            StatColumn(
                                label: "Accuracy",
                                value: String(format: "%.0f%%", team.accuracy * 100),
                                icon: "target"
                            )
                        }
                    }
                }
            }

            // Team Stats
            GlassCard {
                VStack(alignment: .leading, spacing: FFSpacing.md) {
                    Text("Team Stats")
                        .font(FFTypography.headlineSmall)
                        .foregroundColor(FFColors.textPrimary)

                    if isOscarMode {
                        StatRow(label: "Correct Picks", value: "\(team.correctPicks)")
                        StatRow(label: "Total Picks", value: "\(team.totalPicks)")
                        StatRow(label: "Accuracy", value: String(format: "%.1f%%", team.accuracy * 100))
                    } else {
                        StatRow(label: "Movies Drafted", value: "\(team.movieCount)")
                        if let topMovie = team.topMovieTitle {
                            StatRow(label: "Top Movie", value: topMovie)
                        }
                    }
                }
            }
        }
    }

    private func formatScore(_ score: Double) -> String {
        if isOscarMode {
            return "\(Int(score))"
        } else if score >= 1_000_000_000 {
            return String(format: "$%.2fB", score / 1_000_000_000)
        } else if score >= 1_000_000 {
            return String(format: "$%.2fM", score / 1_000_000)
        } else {
            return String(format: "$%.0f", score)
        }
    }
}

struct StatColumn: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: FFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(FFColors.goldPrimary)

            Text(value)
                .font(FFTypography.titleLarge)
                .foregroundColor(FFColors.textPrimary)

            Text(label)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textSecondary)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
            Spacer()
            Text(value)
                .font(FFTypography.labelMedium)
                .foregroundColor(FFColors.textPrimary)
        }
    }
}

// MARK: - Team Summary Card

struct TeamSummaryCard: View {
    let standing: LeagueStanding
    let isOscarMode: Bool

    var body: some View {
        GlassCard {
            HStack(spacing: FFSpacing.md) {
                // Rank Badge
                ZStack {
                    Circle()
                        .fill(FFColors.goldPrimary.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Text("\(standing.rank)")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.goldPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(standing.teamName)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textPrimary)

                    if isOscarMode {
                        Text("\(standing.correctPicks)/\(standing.totalPicks) • \(String(format: "%.0f%%", standing.accuracy * 100))")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textSecondary)
                    }
                }

                Spacer()

                Text(formatScore(standing.totalScore))
                    .font(FFTypography.titleMedium)
                    .foregroundColor(FFColors.goldPrimary)
            }
        }
    }

    private func formatScore(_ score: Double) -> String {
        if isOscarMode {
            return "\(Int(score)) pts"
        } else if score >= 1_000_000 {
            return String(format: "$%.1fM", score / 1_000_000)
        } else {
            return String(format: "$%.0f", score)
        }
    }
}

// MARK: - Scoring Info Card

struct ScoringInfoCard: View {
    let league: FFLeague

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                Text("Scoring Rules")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                if league.isOscarMode, let oscarSettings = league.settings.oscarSettings {
                    VStack(alignment: .leading, spacing: FFSpacing.sm) {
                        ScoringRuleRow(
                            icon: "checkmark.circle.fill",
                            label: "Correct Prediction",
                            value: "\(Int(oscarSettings.pointsPerCorrectPick)) point\(oscarSettings.pointsPerCorrectPick == 1 ? "" : "s")"
                        )

                        if oscarSettings.categoryBonusPoints > 0 {
                            ScoringRuleRow(
                                icon: "star.fill",
                                label: "Category Sweep Bonus",
                                value: "+\(Int(oscarSettings.categoryBonusPoints)) points"
                            )
                        }

                        Divider()

                        Text("Winner: Highest total points")
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textSecondary)
                            .italic()
                    }
                } else {
                    Text(league.settings.scoringMode.displayName)
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textPrimary)
                }
            }
        }
    }
}

struct ScoringRuleRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(FFColors.goldPrimary)
                .frame(width: 20)

            Text(label)
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)

            Spacer()

            Text(value)
                .font(FFTypography.labelMedium)
                .foregroundColor(FFColors.textPrimary)
        }
    }
}

// MARK: - Oscar Scoring Breakdown

struct OscarScoringBreakdown: View {
    let standings: [LeagueStanding]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                Text("Category Breakdown")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Text("Detailed category-by-category results will appear after the Oscar ceremony")
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textSecondary)
                    .italic()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LeagueDashboardView(league: .sample)
            .ffTheme()
    }
}
