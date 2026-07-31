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
    @State private var showInviteFriends = false
    @State private var showEditSettings = false
    /// Genre id -> name, so the filter chips can read "Comedy, Horror" rather
    /// than "2 selected".
    @State private var genreNames: [Int: String] = [:]

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

                    // Error display
                    if let error = viewModel.error {
                        HStack(spacing: FFSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(FFColors.ruby)
                            Text(error)
                                .font(FFTypography.bodySmall)
                                .foregroundColor(FFColors.textPrimary)
                            Spacer()
                            Button {
                                viewModel.error = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(FFColors.textTertiary)
                            }
                        }
                        .padding(FFSpacing.md)
                        .background(FFColors.ruby.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, FFSpacing.xl)
            }
        }
        .navigationTitle("Movie Night")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadGenreNames()
        }
        .sheet(isPresented: $showEditSettings) {
            if let filters = viewModel.session?.filters {
                EditSessionSettingsSheet(
                    filters: filters,
                    onSave: { updated in
                        Task { await viewModel.updateSessionFilters(updated) }
                    }
                )
            }
        }
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

                HStack(spacing: FFSpacing.sm) {
                    // Invite friends button (primary)
                    Button {
                        showInviteFriends = true
                    } label: {
                        HStack(spacing: FFSpacing.xs) {
                            Image(systemName: "person.2.fill")
                            Text("Invite Friends")
                        }
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.backgroundDark)
                        .padding(.horizontal, FFSpacing.lg)
                        .padding(.vertical, FFSpacing.sm)
                        .background(FFColors.goldGradient)
                        .clipShape(Capsule())
                    }

                    // Copy button
                    Button {
                        if let code = viewModel.session?.inviteCode {
                            UIPasteboard.general.string = code
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.goldPrimary)
                            .frame(width: 40, height: 36)
                            .background(FFColors.goldPrimary.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    // Share button
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.goldPrimary)
                            .frame(width: 40, height: 36)
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
        .sheet(isPresented: $showInviteFriends) {
            if let session = viewModel.session {
                InviteFriendsSheet(sessionId: session.id, inviteCode: session.inviteCode)
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
                HStack {
                    Text("Session Settings")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textTertiary)

                    Spacer()

                    if viewModel.isHost {
                        Button {
                            showEditSettings = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Edit")
                                    .font(FFTypography.labelSmall)
                            }
                            .foregroundColor(FFColors.goldPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(FFColors.goldPrimary.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }

                if let filters = viewModel.session?.filters {
                    VStack(alignment: .leading, spacing: FFSpacing.md) {
                        // One chip per active filter, wrapping onto as many
                        // lines as it takes. Everyone in the lobby should be
                        // able to see exactly what the deck was built from
                        // before they start swiping.
                        let chips = filters.activeSummaryChips(genreNames: genreNames)
                        if chips.isEmpty {
                            Text("No filters — anything goes.")
                                .font(FFTypography.bodySmall)
                                .foregroundColor(FFColors.textSecondary)
                        } else {
                            FlowChips(chips: chips)
                        }

                        Divider().background(Color.white.opacity(0.08))

                        HStack(spacing: FFSpacing.lg) {
                            filterPill(icon: "square.stack.fill", value: "\(filters.deckSize) movies")
                            if filters.includeNowPlaying {
                                filterPill(icon: "popcorn.fill", value: "In theaters")
                            }
                            if filters.includeTrending {
                                filterPill(icon: "flame.fill", value: "Recent")
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func loadGenreNames() async {
        let genres = (try? await TMDBService.shared.getGenres()) ?? MovieNightSetupView.fallbackGenres
        genreNames = Dictionary(uniqueKeysWithValues: genres.map { ($0.id, $0.name) })
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

// MARK: - Edit Session Settings Sheet

/// Host-only filter editor, shown from the lobby before swiping starts.
///
/// Renders the same sections as the setup flow, so every filter the host could
/// pick when creating the session can also be changed here — the previous
/// hand-written copy silently omitted several.
struct EditSessionSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var filters: MovieNightFilters
    @State private var genres: [Genre] = []
    @State private var isLoadingGenres = true
    let onSave: (MovieNightFilters) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: FFSpacing.lg) {
                            GlassCard {
                                MovieNightMoodSection(
                                    filters: $filters,
                                    genres: genres,
                                    isLoading: isLoadingGenres
                                )
                            }
                            GlassCard { MovieNightWhereSection(filters: $filters) }
                            GlassCard { MovieNightLengthSection(filters: $filters) }
                            GlassCard { MovieNightRatingSection(filters: $filters) }
                            GlassCard { MovieNightEraSection(filters: $filters) }
                            GlassCard { MovieNightAudienceSection(filters: $filters) }
                            GlassCard { MovieNightQualitySection(filters: $filters) }
                            GlassCard { MovieNightSourcesSection(filters: $filters) }
                            GlassCard { MovieNightWatchedSection(filters: $filters) }
                            GlassCard { MovieNightDeckSizeSection(filters: $filters) }

                            Spacer(minLength: FFSpacing.xl)
                        }
                        .padding()
                    }

                    MovieNightMatchCountBar(filters: filters)
                        .padding(.horizontal)
                        .padding(.bottom, FFSpacing.sm)
                }
            }
            .navigationTitle("Edit Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(filters)
                        dismiss()
                    }
                    .foregroundColor(FFColors.goldPrimary)
                    .fontWeight(.semibold)
                }
            }
            .task {
                genres = (try? await TMDBService.shared.getGenres()) ?? MovieNightSetupView.fallbackGenres
                isLoadingGenres = false
            }
        }
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

