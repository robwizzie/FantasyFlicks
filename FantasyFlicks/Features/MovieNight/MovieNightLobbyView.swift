//
//  MovieNightLobbyView.swift
//  FantasyFlicks
//
//  Waiting room where participants join before swiping begins
//

import SwiftUI

struct MovieNightLobbyView: View {
    @ObservedObject var viewModel: MovieNightViewModel
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: FFSpacing.xxl) {
                    // Header
                    headerSection

                    // Invite code card
                    inviteCodeCard

                    // Participants
                    participantsSection

                    // Filter summary
                    filterSummary

                    // Start button (host only)
                    if viewModel.isHost {
                        startButton
                    } else {
                        waitingForHostView
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, FFSpacing.xl)
            }
        }
        .navigationTitle("Movie Night")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: FFSpacing.md) {
            Image(systemName: "popcorn.fill")
                .font(.system(size: 56))
                .foregroundStyle(FFColors.goldGradient)

            Text("Movie Night")
                .font(FFTypography.displaySmall)
                .foregroundColor(FFColors.textPrimary)

            Text("Share the code or start solo")
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Invite Code

    private var inviteCodeCard: some View {
        GlassCard(goldTint: true) {
            VStack(spacing: FFSpacing.lg) {
                Text("INVITE CODE")
                    .font(FFTypography.overline)
                    .foregroundColor(FFColors.textTertiary)

                Text(viewModel.session?.inviteCode ?? "------")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(FFColors.goldGradient)
                    .tracking(8)

                HStack(spacing: FFSpacing.md) {
                    // Copy button
                    Button {
                        if let code = viewModel.session?.inviteCode {
                            UIPasteboard.general.string = code
                        }
                    } label: {
                        HStack(spacing: FFSpacing.sm) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.goldPrimary)
                        .padding(.horizontal, FFSpacing.lg)
                        .padding(.vertical, FFSpacing.sm)
                        .background(FFColors.goldPrimary.opacity(0.15))
                        .clipShape(Capsule())
                    }

                    // Share button
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack(spacing: FFSpacing.sm) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.goldPrimary)
                        .padding(.horizontal, FFSpacing.lg)
                        .padding(.vertical, FFSpacing.sm)
                        .background(FFColors.goldPrimary.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showShareSheet) {
            if let code = viewModel.session?.inviteCode {
                ShareSheet(items: ["Join my Movie Night on FantasyFlicks! Code: \(code)"])
            }
        }
    }

    // MARK: - Participants

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Participants")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                Text("\(viewModel.session?.participantCount ?? 0) joined")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.goldPrimary)
            }
            .padding(.horizontal)

            VStack(spacing: FFSpacing.sm) {
                if let session = viewModel.session {
                    ForEach(session.participantIds, id: \.self) { userId in
                        participantRow(
                            name: session.participantNames[userId] ?? "Player",
                            isHost: userId == session.hostId
                        )
                    }
                }
            }
            .padding(.horizontal)

            // Waiting indicator
            HStack(spacing: FFSpacing.sm) {
                ProgressView()
                    .tint(FFColors.goldPrimary)
                    .scaleEffect(0.8)
                Text("Waiting for more friends to join...")
                    .font(FFTypography.bodySmall)
                    .foregroundColor(FFColors.textTertiary)
            }
            .padding(.horizontal)
        }
    }

    private func participantRow(name: String, isHost: Bool) -> some View {
        CompactGlassCard {
            HStack(spacing: FFSpacing.md) {
                // Avatar
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(name.prefix(1)).uppercased())
                            .font(FFTypography.labelLarge)
                            .foregroundColor(FFColors.goldPrimary)
                    }

                Text(name)
                    .font(FFTypography.titleSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                if isHost {
                    Badge(text: "Host", style: .gold)
                }

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(FFColors.success)
            }
        }
    }

    // MARK: - Filter Summary

    private var filterSummary: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                Text("Session Settings")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textTertiary)

                if let filters = viewModel.session?.filters {
                    HStack(spacing: FFSpacing.lg) {
                        filterPill(icon: "star.fill", value: String(format: "%.1f+", filters.minVoteAverage))
                        filterPill(icon: "square.stack.fill", value: "\(filters.deckSize) movies")
                        if !filters.watchProviderIds.isEmpty {
                            filterPill(icon: "play.tv.fill", value: "\(filters.watchProviderIds.count) services")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func filterPill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(FFColors.goldPrimary)
            Text(value)
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textSecondary)
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        VStack(spacing: FFSpacing.sm) {
            GoldButton(
                title: viewModel.isLoading ? "Building Deck..." : "Start Swiping!",
                icon: "hand.draw.fill",
                style: .ruby,
                size: .large,
                isLoading: viewModel.isLoading,
                fullWidth: true
            ) {
                Task { await viewModel.startSwiping() }
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal)

            if (viewModel.session?.participantCount ?? 0) < 2 {
                Text("You can start solo or wait for friends to join")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
            }
        }
    }

    private var waitingForHostView: some View {
        VStack(spacing: FFSpacing.md) {
            ProgressView()
                .tint(FFColors.goldPrimary)
            Text("Waiting for host to start...")
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
        }
        .padding(.vertical, FFSpacing.xl)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

