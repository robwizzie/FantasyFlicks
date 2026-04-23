//
//  MovieNightEntryView.swift
//  FantasyFlicks
//
//  Entry point for the Movie Night feature — host, join, or resume sessions
//

import SwiftUI

struct MovieNightEntryView: View {
    @StateObject private var viewModel = MovieNightViewModel()
    @State private var joinCode = ""
    @State private var showJoinField = false
    @State private var sessionToDelete: MovieNightSession?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.xxl) {
                        // Hero
                        heroSection

                        // Main actions
                        actionsSection

                        // Join code field
                        if showJoinField {
                            joinSection
                        }

                        // Recent sessions
                        if !viewModel.userSessions.isEmpty {
                            recentSessionsSection
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, FFSpacing.xl)
                }

                // Error
                if let error = viewModel.error {
                    VStack {
                        Spacer()
                        errorBanner(message: error)
                    }
                }
            }
            .navigationTitle("Movie Night")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: { viewModel.currentPhase == .setup },
                set: { if !$0 { viewModel.currentPhase = .entry } }
            )) {
                MovieNightSetupView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: Binding(
                get: { viewModel.currentPhase == .lobby },
                set: { if !$0 { viewModel.currentPhase = .entry } }
            )) {
                MovieNightLobbyView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: Binding(
                get: { viewModel.currentPhase == .swiping },
                set: { _ in } // Prevent back-swipe from exiting swiping — must finish
            )) {
                MovieNightSwipeView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: Binding(
                get: { viewModel.currentPhase == .results },
                set: { if !$0 { viewModel.currentPhase = .entry } }
            )) {
                MovieNightResultsView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadUserSessions()
                // Auto-resume a session if one was pending from the history tab
                if let pendingId = NavigationCoordinator.shared.pendingResumeSessionId,
                   let session = viewModel.userSessions.first(where: { $0.id == pendingId }) {
                    viewModel.resumeSession(session)
                    NavigationCoordinator.shared.pendingResumeSessionId = nil
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            VStack {
                EllipticalGradient(
                    colors: [
                        FFColors.ruby.opacity(0.12),
                        FFColors.goldPrimary.opacity(0.06),
                        Color.clear
                    ],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.5
                )
                .frame(height: 400)
                .blur(radius: 60)

                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: FFSpacing.lg) {
            // Animated popcorn icon
            Image(systemName: "popcorn.fill")
                .font(.system(size: 72))
                .foregroundStyle(FFColors.goldGradient)
                .shadow(color: FFColors.goldPrimary.opacity(0.4), radius: 20, x: 0, y: 0)

            VStack(spacing: FFSpacing.sm) {
                Text("Movie Night")
                    .font(FFTypography.displayMedium)
                    .foregroundColor(FFColors.textPrimary)

                Text("Swipe, match, and find the perfect movie\nfor you or your group in minutes")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, FFSpacing.xl)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: FFSpacing.md) {
            // Host button
            GoldButton(
                title: "Host Movie Night",
                icon: "plus.circle.fill",
                style: .primary,
                size: .large,
                fullWidth: true
            ) {
                viewModel.currentPhase = .setup
            }

            // Join button
            GoldButton(
                title: "Join with Code",
                icon: "person.badge.plus",
                style: .secondary,
                size: .large,
                fullWidth: true
            ) {
                withAnimation(FFAnimations.snappy) {
                    showJoinField.toggle()
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Join Section

    private var joinSection: some View {
        GlassCard(goldTint: true) {
            VStack(spacing: FFSpacing.lg) {
                Text("Enter Invite Code")
                    .font(FFTypography.titleSmall)
                    .foregroundColor(FFColors.textPrimary)

                HStack(spacing: FFSpacing.sm) {
                    TextField("ABC123", text: $joinCode)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(FFColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(FFSpacing.md)
                        .background(FFColors.backgroundDark.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
                        }
                }

                GoldButton(
                    title: viewModel.isLoading ? "Joining..." : "Join Session",
                    style: .ruby,
                    size: .medium,
                    isLoading: viewModel.isLoading,
                    fullWidth: true
                ) {
                    Task { await viewModel.joinSession(inviteCode: joinCode) }
                }
                .disabled(joinCode.count < 6 || viewModel.isLoading)
            }
        }
        .padding(.horizontal)
        .transition(FFTransitions.slideUp)
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Your Sessions")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            VStack(spacing: FFSpacing.sm) {
                ForEach(viewModel.userSessions) { session in
                    sessionRow(session: session)
                }
            }
        }
        .alert("Delete Movie Night?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    Task { await viewModel.deleteSession(session) }
                }
            }
        } message: {
            Text("This will permanently remove this session.")
        }
    }

    private func sessionRow(session: MovieNightSession) -> some View {
        HStack(spacing: FFSpacing.md) {
            // Main tappable area
            Button {
                viewModel.resumeSession(session)
            } label: {
                HStack(spacing: FFSpacing.md) {
                    Image(systemName: session.status.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(statusColor(for: session.status))
                        .frame(width: 44, height: 44)
                        .background(statusColor(for: session.status).opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.participantNames.values.joined(separator: ", "))
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: FFSpacing.sm)

                            Badge(text: session.status.displayName,
                                  style: session.status == .results ? .gold : .default)
                        }

                        HStack(spacing: FFSpacing.md) {
                            Label("\(session.participantCount)", systemImage: "person.2.fill")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)

                            Text(session.createdAt, style: .relative)
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Separate delete button
            Button {
                sessionToDelete = session
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(FFColors.ruby.opacity(0.7))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FFSpacing.md)
        .padding(.vertical, FFSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
        .padding(.horizontal)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(FFColors.ruby)
            Text(message)
                .font(FFTypography.bodySmall)
                .foregroundColor(FFColors.textPrimary)
            Spacer()
            Button {
                viewModel.error = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(FFColors.textTertiary)
            }
        }
        .padding(FFSpacing.md)
        .background(FFColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
        .padding()
    }

    // MARK: - Helpers

    private func statusColor(for status: MovieNightStatus) -> Color {
        switch status {
        case .lobby: return FFColors.goldPrimary
        case .swiping: return FFColors.ruby
        case .results: return FFColors.success
        case .expired: return FFColors.textTertiary
        }
    }
}

// MARK: - How It Works

struct HowItWorksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.lg) {
            Text("How It Works")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)

            howItWorksStep(number: 1, icon: "slider.horizontal.3", title: "Pick Filters", description: "Choose genres, streaming services, and quality")
            howItWorksStep(number: 2, icon: "link", title: "Invite Friends", description: "Share the code and wait for everyone to join")
            howItWorksStep(number: 3, icon: "hand.draw.fill", title: "Swipe Movies", description: "Right for yes, left for no — just like Tinder!")
            howItWorksStep(number: 4, icon: "trophy.fill", title: "See Matches", description: "Find out what everyone wants to watch")
        }
        .padding(.horizontal)
    }

    private func howItWorksStep(number: Int, icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: FFSpacing.md) {
            ZStack {
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(FFColors.goldPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FFTypography.labelLarge)
                    .foregroundColor(FFColors.textPrimary)
                Text(description)
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textSecondary)
            }
        }
    }
}
