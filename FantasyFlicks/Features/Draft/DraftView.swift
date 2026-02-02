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
                    // Segment control
                    Picker("View", selection: $selectedSegment) {
                        Text("Upcoming").tag(0)
                        Text("Active").tag(1)
                        Text("Completed").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Content
                    TabView(selection: $selectedSegment) {
                        upcomingDraftsSection.tag(0)
                        activeDraftsSection.tag(1)
                        completedDraftsSection.tag(2)
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

    private var upcomingDraftsSection: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                if viewModel.upcomingDrafts.isEmpty {
                    emptyStateView(
                        icon: "calendar",
                        title: "No Upcoming Drafts",
                        message: "Join a league to participate in drafts"
                    )
                } else {
                    ForEach(viewModel.upcomingDrafts) { draft in
                        GlassCard(goldTint: draft.draftStatus == .scheduled) {
                            VStack(alignment: .leading, spacing: FFSpacing.md) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(draft.leagueName)
                                            .font(FFTypography.titleMedium)
                                            .foregroundColor(FFColors.textPrimary)

                                        Text(draft.draftStatus == .scheduled ? "Draft scheduled" : "Waiting for members")
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
                                    }
                                }

                                Divider().background(Color.white.opacity(0.1))

                                HStack {
                                    InfoPill(icon: "person.2.fill", text: "\(draft.memberCount)/\(draft.maxMembers) members")
                                    Spacer()
                                    Text("\(draft.moviesPerPlayer) movies each")
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
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
                            DraftStep(number: 2, text: "Commissioner schedules the draft")
                            DraftStep(number: 3, text: "Take turns picking movies")
                            DraftStep(number: 4, text: "Track your movies' performance!")
                        }
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }

    private var activeDraftsSection: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                if viewModel.activeDrafts.isEmpty {
                    emptyStateView(
                        icon: "play.circle",
                        title: "No Active Drafts",
                        message: "When a draft starts, it will appear here"
                    )
                } else {
                    ForEach(viewModel.activeDrafts) { draft in
                        NavigationLink {
                            DraftRoomView(draftId: draft.id, leagueName: draft.leagueName)
                        } label: {
                            GlassCard {
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

                                    if draft.isYourTurn {
                                        // Timer
                                        HStack {
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(FFColors.warning)
                                            Text("\(viewModel.remainingTime / 60):\(String(format: "%02d", viewModel.remainingTime % 60)) remaining")
                                                .font(FFTypography.statSmall)
                                                .foregroundColor(FFColors.warning)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(FFColors.warning.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))

                                        Text("Enter Draft Room")
                                            .font(FFTypography.labelMedium)
                                            .foregroundColor(FFColors.backgroundDark)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(FFColors.ruby)
                                            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                                    } else {
                                        Text("Watch Draft")
                                            .font(FFTypography.labelMedium)
                                            .foregroundColor(FFColors.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(FFColors.backgroundElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
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
                                    Text("\(draft.moviesPerPlayer) movies")
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
