//
//  LeagueCard.swift
//  FantasyFlicks
//
//  League card component for displaying league information
//

import SwiftUI

/// Card displaying league information
struct LeagueCard: View {
    let league: FFLeague
    var showMembers: Bool = true
    var compact: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap = onTap {
                Button {
                    onTap()
                } label: {
                    cardContent
                }
                .buttonStyle(.plain)
                .pressEffect()
            } else {
                cardContent
            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        if compact {
            compactLayout
        } else {
            fullLayout
        }
    }

    private var fullLayout: some View {
        GlassCard(goldTint: league.draftStatus == .inProgress) {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(league.name)
                            .font(FFTypography.titleMedium)
                            .foregroundColor(FFColors.textPrimary)
                            .lineLimit(1)

                        Text("\(String(league.seasonYear)) Season")
                            .font(FFTypography.labelSmall)
                            .foregroundColor(FFColors.textSecondary)
                    }

                    Spacer()

                    statusBadge
                }

                // Description
                if let description = league.description {
                    Text(description)
                        .font(FFTypography.bodySmall)
                        .foregroundColor(FFColors.textSecondary)
                        .lineLimit(2)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Info row
                HStack(spacing: FFSpacing.lg) {
                    // Members
                    if showMembers {
                        InfoPill(
                            icon: "person.2.fill",
                            text: "\(league.memberCount)/\(league.maxMembers)"
                        )
                    }

                    // Scoring mode
                    InfoPill(
                        icon: league.settings.scoringMode.icon,
                        text: league.settings.scoringMode.displayName
                    )

                    Spacer()

                    // Draft info
                    if let scheduledDate = league.draftScheduledAt, league.draftStatus == .scheduled {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Draft")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                            Text(scheduledDate, format: .dateTime.month(.abbreviated).day())
                                .font(FFTypography.labelSmall)
                                .foregroundColor(FFColors.goldPrimary)
                        }
                    }
                }
            }
        }
    }

    private var compactLayout: some View {
        CompactGlassCard {
            HStack(spacing: FFSpacing.md) {
                // League icon
                ZStack {
                    Circle()
                        .fill(FFColors.goldPrimary.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18))
                        .foregroundColor(FFColors.goldPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(league.name)
                        .font(FFTypography.titleSmall)
                        .foregroundColor(FFColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: FFSpacing.sm) {
                        Text("\(league.memberCount) members")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textSecondary)

                        Text("•")
                            .foregroundColor(FFColors.textTertiary)

                        Text(league.settings.scoringMode.displayName)
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textSecondary)
                    }
                }

                Spacer()

                statusIndicator
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            if league.draftStatus == .inProgress {
                Circle()
                    .fill(FFColors.ruby)
                    .frame(width: 8, height: 8)
            }

            Text(league.draftStatus.displayName)
                .font(FFTypography.labelSmall)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, FFSpacing.sm)
        .padding(.vertical, FFSpacing.xs)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    private var statusColor: Color {
        switch league.draftStatus {
        case .pending: return FFColors.textSecondary
        case .scheduled: return FFColors.goldPrimary
        case .inProgress: return FFColors.ruby
        case .paused: return FFColors.warning
        case .completed: return FFColors.success
        }
    }
}

// MARK: - Info Pill

struct InfoPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(FFTypography.labelSmall)
        }
        .foregroundColor(FFColors.textSecondary)
    }
}

// MARK: - Join League Card

struct JoinLeagueCard: View {
    var onCreateTap: () -> Void
    var onJoinTap: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: FFSpacing.lg) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(FFColors.goldGradient)

                VStack(spacing: FFSpacing.sm) {
                    Text("Join the Competition")
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.textPrimary)

                    Text("Create your own league or join one with friends")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: FFSpacing.md) {
                    GoldButton(title: "Create", icon: "plus", style: .primary, size: .medium, action: onCreateTap)

                    GoldButton(title: "Join", icon: "person.badge.plus", style: .secondary, size: .medium, action: onJoinTap)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Standings Card

struct StandingsCard: View {
    let standings: [FFTeamStanding]
    let currentUserId: String
    var onTap: (() -> Void)?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                // Header
                HStack {
                    Text("Standings")
                        .font(FFTypography.headlineSmall)
                        .foregroundColor(FFColors.textPrimary)

                    Spacer()

                    if onTap != nil {
                        Button {
                            onTap?()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Full Standings")
                                    .font(FFTypography.labelSmall)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(FFColors.goldPrimary)
                        }
                    }
                }

                // Top 3 standings
                VStack(spacing: FFSpacing.sm) {
                    ForEach(standings.prefix(3)) { standing in
                        StandingRow(
                            standing: standing,
                            isCurrentUser: standing.userId == currentUserId
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Standing Row

struct StandingRow: View {
    let standing: FFTeamStanding
    var isCurrentUser: Bool = false

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            // Rank
            ZStack {
                if standing.rank <= 3 {
                    Circle()
                        .fill(rankColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                }

                Text("\(standing.rank)")
                    .font(FFTypography.titleSmall)
                    .foregroundColor(standing.rank <= 3 ? rankColor : FFColors.textSecondary)
            }
            .frame(width: 32)

            // Team info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: FFSpacing.xs) {
                    Text(standing.teamName)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(isCurrentUser ? FFColors.goldPrimary : FFColors.textPrimary)

                    if isCurrentUser {
                        Text("(You)")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }

                if let topMovie = standing.topMovieTitle {
                    Text("Top: \(topMovie)")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedScore)
                    .font(FFTypography.statSmall)
                    .foregroundColor(FFColors.textPrimary)

                if let change = standing.rankChange, change != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: standing.rankChangeIcon ?? "minus")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(change))")
                            .font(FFTypography.caption)
                    }
                    .foregroundColor(change > 0 ? FFColors.success : FFColors.ruby)
                }
            }
        }
        .padding(.vertical, FFSpacing.xs)
    }

    private var rankColor: Color {
        switch standing.rank {
        case 1: return FFColors.goldPrimary
        case 2: return Color(hex: "C0C0C0") // Silver
        case 3: return Color(hex: "CD7F32") // Bronze
        default: return FFColors.textSecondary
        }
    }

    private var formattedScore: String {
        if standing.totalScore >= 1_000_000_000 {
            return String(format: "$%.2fB", standing.totalScore / 1_000_000_000)
        } else if standing.totalScore >= 1_000_000 {
            return String(format: "$%.1fM", standing.totalScore / 1_000_000)
        } else {
            return String(format: "%.0f", standing.totalScore)
        }
    }
}

// MARK: - Previews

#Preview("League Cards") {
    ZStack {
        FFColors.backgroundDark.ignoresSafeArea()

        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                LeagueCard(league: .sample)

                LeagueCard(league: FFLeague.sampleLeagues[2])

                LeagueCard(league: .sample, compact: true)

                JoinLeagueCard(onCreateTap: {}, onJoinTap: {})

                StandingsCard(
                    standings: FFTeamStanding.sampleStandings,
                    currentUserId: "user_001"
                )
            }
            .padding()
        }
    }
}
