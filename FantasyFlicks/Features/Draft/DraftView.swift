//
//  DraftView.swift
//  FantasyFlicks
//
//  Draft tab - draft room and board
//

import SwiftUI

struct DraftView: View {
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
                        upcomingDrafts.tag(0)
                        activeDrafts.tag(1)
                        completedDrafts.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Drafts")
        }
    }

    private var upcomingDrafts: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                // Upcoming draft card
                GlassCard(goldTint: true) {
                    VStack(alignment: .leading, spacing: FFSpacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Box Office Champions")
                                    .font(FFTypography.titleMedium)
                                    .foregroundColor(FFColors.textPrimary)

                                Text("Draft scheduled")
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textSecondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Feb 5")
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.goldPrimary)

                                Text("8:00 PM")
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textSecondary)
                            }
                        }

                        Divider().background(Color.white.opacity(0.1))

                        HStack {
                            InfoPill(icon: "person.2.fill", text: "4/8 members")
                            Spacer()
                            GoldButton(title: "View Details", size: .small) {}
                        }
                    }
                }
                .padding(.horizontal)

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

    private var activeDrafts: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                // Active draft card
                Button {
                    // Navigate to draft room
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

                                Text("Round 2, Pick 3")
                                    .font(FFTypography.labelSmall)
                                    .foregroundColor(FFColors.textSecondary)
                            }

                            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                Text("Sleeper Hits League")
                                    .font(FFTypography.titleMedium)
                                    .foregroundColor(FFColors.textPrimary)

                                Text("It's your turn to pick!")
                                    .font(FFTypography.bodyMedium)
                                    .foregroundColor(FFColors.goldPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Timer
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(FFColors.warning)
                                Text("1:45 remaining")
                                    .font(FFTypography.statSmall)
                                    .foregroundColor(FFColors.warning)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(FFColors.warning.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))

                            GoldButton(title: "Enter Draft Room", icon: "play.fill", style: .ruby, fullWidth: true) {}
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }

    private var completedDrafts: some View {
        ScrollView {
            VStack(spacing: FFSpacing.md) {
                ForEach(0..<3, id: \.self) { index in
                    CompactGlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Critics Corner")
                                    .font(FFTypography.titleSmall)
                                    .foregroundColor(FFColors.textPrimary)

                                Text("Completed Jan 15, 2026")
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textSecondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("5 movies")
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

                Spacer(minLength: 100)
            }
            .padding()
        }
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
