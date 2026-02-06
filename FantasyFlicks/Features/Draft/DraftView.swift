//
//  DraftView.swift
//  FantasyFlicks
//
//  Draft tab - draft room and board
//

import SwiftUI

struct DraftView: View {
    @StateObject private var viewModel = DraftViewModel()
    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segment control - simplified to 2 tabs
                    Picker("View", selection: $selectedSegment) {
                        Text("Drafts").tag(0)
                        Text("Completed").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Content
                    TabView(selection: $selectedSegment) {
                        allDraftsSection.tag(0)
                        completedDraftsSection.tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Drafts")
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    // MARK: - Combined Active + Upcoming Drafts (Active shown first)

    private var allDraftsSection: some View {
        ScrollView {
            VStack(spacing: FFSpacing.lg) {
                // Active Drafts Section (Priority - shown first)
                if !viewModel.activeDrafts.isEmpty {
                    VStack(alignment: .leading, spacing: FFSpacing.md) {
                        HStack(spacing: FFSpacing.sm) {
                            Circle()
                                .fill(FFColors.ruby)
                                .frame(width: 8, height: 8)
                            Text("LIVE DRAFTS")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.ruby)
                        }
                        .padding(.horizontal)

                        ForEach(viewModel.activeDrafts) { draft in
                            NavigationLink {
                                if draft.isOscarMode, let draftId = draft.draftId {
                                    OscarDraftView(draftId: draftId, leagueId: draft.leagueId, leagueName: draft.leagueName)
                                } else if let draftId = draft.draftId {
                                    DraftRoomView(draftId: draftId, leagueName: draft.leagueName)
                                } else {
                                    DraftRoomView(draftId: draft.id, leagueName: draft.leagueName)
                                }
                            } label: {
                                activeDraftCard(draft: draft)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Upcoming Drafts Section
                if !viewModel.upcomingDrafts.isEmpty {
                    VStack(alignment: .leading, spacing: FFSpacing.md) {
                        HStack(spacing: FFSpacing.sm) {
                            Image(systemName: "calendar")
                                .foregroundColor(FFColors.goldPrimary)
                            Text("UPCOMING")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.goldPrimary)
                        }
                        .padding(.horizontal)

                        ForEach(viewModel.upcomingDrafts) { draft in
                            upcomingDraftCard(draft: draft)
                        }
                    }
                }

                // Empty state if no drafts at all
                if viewModel.activeDrafts.isEmpty && viewModel.upcomingDrafts.isEmpty {
                    emptyStateView(
                        icon: "film.stack",
                        title: "No Drafts Yet",
                        message: "Join a league to participate in drafts"
                    )
                }

                // How drafting works
                GlassCard {
                    VStack(alignment: .leading, spacing: FFSpacing.md) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(FFColors.goldGradient)

                            Text("How Drafting Works")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: FFSpacing.sm) {
                            DraftStep(number: 1, text: "Wait for all league members to join")
                            DraftStep(number: 2, text: "Commissioner starts the draft")
                            DraftStep(number: 3, text: "Take turns making your picks")
                            DraftStep(number: 4, text: "Track your performance!")
                        }
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Active Draft Card

    private func activeDraftCard(draft: DraftViewModel.DraftInfo) -> some View {
        GlassCard(goldTint: draft.isYourTurn) {
            VStack(spacing: FFSpacing.md) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(FFColors.ruby)
                            .frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FFColors.ruby)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FFColors.ruby.opacity(0.2))
                    .clipShape(Capsule())

                    Spacer()

                    Text("Round \(draft.currentRound), Pick \(draft.currentPickInRound)")
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text(draft.leagueName)
                        .font(FFTypography.titleMedium)
                        .foregroundColor(FFColors.textPrimary)

                    Text(draft.isYourTurn ? "It's your turn to pick!" : "Waiting for pick...")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(draft.isYourTurn ? FFColors.goldPrimary : FFColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Always show "Join Draft" button for active drafts
                HStack(spacing: FFSpacing.md) {
                    if draft.isYourTurn && viewModel.remainingTime > 0 {
                        // Timer (only show when there's a time limit)
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(FFColors.warning)
                            Text("\(viewModel.remainingTime / 60):\(String(format: "%02d", viewModel.remainingTime % 60))")
                                .font(FFTypography.statSmall)
                                .foregroundColor(FFColors.warning)
                        }
                        .padding(.horizontal, FFSpacing.md)
                        .padding(.vertical, FFSpacing.sm)
                        .background(FFColors.warning.opacity(0.15))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    // Join Draft button - always visible for active drafts
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text(draft.isYourTurn ? "Join Draft" : "Watch Draft")
                            .font(FFTypography.labelMedium)
                    }
                    .foregroundColor(FFColors.backgroundDark)
                    .padding(.horizontal, FFSpacing.lg)
                    .padding(.vertical, FFSpacing.sm)
                    .background {
                        if draft.isYourTurn {
                            FFColors.ruby
                        } else {
                            FFColors.goldGradientHorizontal
                        }
                    }
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Upcoming Draft Card

    private func upcomingDraftCard(draft: DraftViewModel.DraftInfo) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.leagueName)
                            .font(FFTypography.titleMedium)
                            .foregroundColor(FFColors.textPrimary)

                        Text(draft.draftStatus == .scheduled ? "Draft scheduled" : "Waiting to start")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textSecondary)
                    }

                    Spacer()

                    if let scheduledAt = draft.scheduledAt {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(scheduledAt, format: .dateTime.month().day())
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.goldPrimary)

                            Text(scheduledAt, format: .dateTime.hour().minute())
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textSecondary)
                        }
                    } else {
                        Text("Pending")
                            .font(FFTypography.labelSmall)
                            .foregroundColor(FFColors.textTertiary)
                            .padding(.horizontal, FFSpacing.sm)
                            .padding(.vertical, FFSpacing.xs)
                            .background(FFColors.backgroundElevated)
                            .clipShape(Capsule())
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    InfoPill(icon: "person.2.fill", text: "\(draft.memberCount)/\(draft.maxMembers) members")
                    Spacer()
                    Text(draft.isOscarMode ? "\(draft.moviesPerPlayer) picks each" : "\(draft.moviesPerPlayer) movies each")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }
            }
        }
        .padding(.horizontal)
    }

    private var completedDraftsSection: some View {
        ScrollView {
            VStack(spacing: FFSpacing.md) {
                if viewModel.completedDrafts.isEmpty {
                    emptyStateView(
                        icon: "checkmark.circle",
                        title: "No Completed Drafts",
                        message: "Completed drafts will appear here"
                    )
                } else {
                    ForEach(viewModel.completedDrafts) { draft in
                        CompactGlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(draft.leagueName)
                                        .font(FFTypography.titleSmall)
                                        .foregroundColor(FFColors.textPrimary)

                                    if let completedAt = draft.completedAt {
                                        Text("Completed \(completedAt, format: .dateTime.month().day().year())")
                                            .font(FFTypography.caption)
                                            .foregroundColor(FFColors.textSecondary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(draft.isOscarMode ? "\(draft.moviesPerPlayer) picks" : "\(draft.moviesPerPlayer) movies")
                                        .font(FFTypography.labelSmall)
                                        .foregroundColor(FFColors.goldPrimary)

                                    Text("View Results")
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.textTertiary)
                                }

                                Image(systemName: "chevron.right")
                                    .foregroundColor(FFColors.textTertiary)
                            }
                        }
                    }
                }

                Spacer(minLength: 100)
            }
            .padding()
        }
    }

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: FFSpacing.lg) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(FFColors.goldGradient)

            VStack(spacing: FFSpacing.sm) {
                Text(title)
                    .font(FFTypography.headlineMedium)
                    .foregroundColor(FFColors.textPrimary)

                Text(message)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }
}

struct DraftStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: FFSpacing.md) {
            ZStack {
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.2))
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.goldPrimary)
            }

            Text(text)
                .font(FFTypography.bodySmall)
                .foregroundColor(FFColors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    DraftView()
        .ffTheme()
}
