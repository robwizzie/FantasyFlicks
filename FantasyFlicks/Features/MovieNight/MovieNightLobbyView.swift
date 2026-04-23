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
    @State private var showEditSettings = false

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
                    VStack(alignment: .leading, spacing: FFSpacing.sm) {
                        // Genres
                        filterRow(
                            icon: "theatermasks.fill",
                            label: "Genres",
                            value: filters.genreIds.isEmpty
                                ? "All genres"
                                : "\(filters.genreIds.count) selected"
                        )

                        // Streaming
                        filterRow(
                            icon: "play.tv.fill",
                            label: "Streaming",
                            value: filters.watchProviderIds.isEmpty
                                ? "All services"
                                : StreamingProvider.allCases
                                    .filter { filters.watchProviderIds.contains($0.id) }
                                    .map { $0.name }
                                    .joined(separator: ", ")
                        )

                        // Rating + deck
                        HStack(spacing: FFSpacing.lg) {
                            filterPill(icon: "star.fill", value: String(format: "%.1f+", filters.minVoteAverage))
                            filterPill(icon: "square.stack.fill", value: "\(filters.deckSize) movies")
                        }

                        // Sources — wraps to multiple lines
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: FFSpacing.sm) {
                                if filters.includeTrending {
                                    filterPill(icon: "flame.fill", value: "Trending")
                                }
                                if filters.includeNowPlaying {
                                    filterPill(icon: "popcorn.fill", value: "In Theaters")
                                }
                                if filters.excludeSeenMode != .none {
                                    filterPill(icon: "eye.slash.fill", value: filters.excludeSeenMode.displayName)
                                }
                                if let year = filters.minimumYear {
                                    filterPill(icon: "calendar", value: "\(year)+")
                                }
                                if filters.excludeShorts {
                                    filterPill(icon: "timer", value: "No Shorts")
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func filterRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(FFColors.goldPrimary)
                .frame(width: 16)
            Text(label)
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textTertiary)
            Text(value)
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textPrimary)
                .lineLimit(1)
        }
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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: FFSpacing.xxl) {
                        // Genres
                        VStack(alignment: .leading, spacing: FFSpacing.md) {
                            Text("Genres")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)

                            if isLoadingGenres {
                                ProgressView().tint(FFColors.goldPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 60)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FFSpacing.sm) {
                                    ForEach(genres) { genre in
                                        let isSelected = filters.genreIds.contains(genre.id)
                                        Button {
                                            if isSelected {
                                                filters.genreIds.removeAll { $0 == genre.id }
                                            } else {
                                                filters.genreIds.append(genre.id)
                                            }
                                        } label: {
                                            Text(genre.name)
                                                .font(FFTypography.labelSmall)
                                                .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textPrimary)
                                                .padding(.horizontal, FFSpacing.sm)
                                                .padding(.vertical, FFSpacing.xs)
                                                .frame(maxWidth: .infinity)
                                                .background(isSelected ? FFColors.goldPrimary : FFColors.backgroundElevated)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                if filters.genreIds.isEmpty {
                                    Text("None selected = all genres included")
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.textTertiary)
                                }
                            }
                        }

                        // Streaming Services
                        VStack(alignment: .leading, spacing: FFSpacing.md) {
                            Text("Streaming Services")
                                .font(FFTypography.headlineSmall)
                                .foregroundColor(FFColors.textPrimary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FFSpacing.sm) {
                                ForEach(StreamingProvider.allCases) { provider in
                                    let isSelected = filters.watchProviderIds.contains(provider.id)
                                    Button {
                                        if isSelected {
                                            filters.watchProviderIds.removeAll { $0 == provider.id }
                                        } else {
                                            filters.watchProviderIds.append(provider.id)
                                        }
                                    } label: {
                                        HStack(spacing: FFSpacing.sm) {
                                            Image(systemName: provider.iconName)
                                                .font(.system(size: 16))
                                                .foregroundColor(isSelected ? FFColors.backgroundDark : Color(hex: provider.color))
                                                .frame(width: 24)
                                            Text(provider.name)
                                                .font(FFTypography.labelSmall)
                                                .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(FFColors.backgroundDark)
                                            }
                                        }
                                        .padding(FFSpacing.sm)
                                        .background(isSelected ? FFColors.goldPrimary : FFColors.backgroundElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if filters.watchProviderIds.isEmpty {
                                Text("None selected = all services included")
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textTertiary)
                            }
                        }

                        // Rating
                        GlassCard {
                            VStack(alignment: .leading, spacing: FFSpacing.md) {
                                HStack {
                                    Image(systemName: "star.fill").foregroundColor(FFColors.goldPrimary)
                                    Text("Minimum Rating").font(FFTypography.titleSmall).foregroundColor(FFColors.textPrimary)
                                    Spacer()
                                    Text(String(format: "%.1f+", filters.minVoteAverage))
                                        .font(FFTypography.statSmall).foregroundColor(FFColors.goldPrimary)
                                }
                                Slider(value: $filters.minVoteAverage, in: 4.0...8.5, step: 0.5).tint(FFColors.goldPrimary)
                            }
                        }

                        // Year filter
                        GlassCard {
                            VStack(alignment: .leading, spacing: FFSpacing.md) {
                                HStack(spacing: FFSpacing.sm) {
                                    Image(systemName: "calendar").foregroundColor(FFColors.goldPrimary)
                                    Text("Movies From").font(FFTypography.titleSmall).foregroundColor(FFColors.textPrimary)
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: FFSpacing.sm) {
                                        ForEach([("Any", nil as Int?), ("2020+", 2020), ("2010+", 2010), ("2000+", 2000), ("1990+", 1990), ("1980+", 1980)], id: \.0) { label, year in
                                            let isSelected = filters.minimumYear == year
                                            Button { filters.minimumYear = year } label: {
                                                Text(label)
                                                    .font(FFTypography.labelSmall)
                                                    .foregroundColor(isSelected ? FFColors.backgroundDark : FFColors.textPrimary)
                                                    .padding(.horizontal, FFSpacing.md)
                                                    .padding(.vertical, FFSpacing.xs)
                                                    .background(isSelected ? FFColors.goldPrimary : FFColors.backgroundElevated)
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        // Deck Size
                        GlassCard {
                            VStack(alignment: .leading, spacing: FFSpacing.md) {
                                HStack {
                                    Image(systemName: "square.stack.fill").foregroundColor(FFColors.goldPrimary)
                                    Text("Deck Size").font(FFTypography.titleSmall).foregroundColor(FFColors.textPrimary)
                                    Spacer()
                                    Text("\(filters.deckSize) movies")
                                        .font(FFTypography.statSmall).foregroundColor(FFColors.goldPrimary)
                                }
                                Slider(value: Binding(
                                    get: { Double(filters.deckSize) },
                                    set: { filters.deckSize = Int($0) }
                                ), in: 10...40, step: 5).tint(FFColors.goldPrimary)
                            }
                        }

                        // Toggles
                        GlassCard {
                            VStack(spacing: FFSpacing.lg) {
                                Toggle(isOn: $filters.excludeShorts) {
                                    HStack(spacing: FFSpacing.sm) {
                                        Image(systemName: "timer").foregroundColor(FFColors.goldPrimary)
                                        Text("Exclude Short Films").font(FFTypography.labelLarge).foregroundColor(FFColors.textPrimary)
                                    }
                                }.tint(FFColors.goldPrimary)

                                Divider().background(Color.white.opacity(0.1))

                                Toggle(isOn: $filters.includeTrending) {
                                    HStack(spacing: FFSpacing.sm) {
                                        Image(systemName: "flame.fill").foregroundColor(FFColors.ruby)
                                        Text("Include Trending").font(FFTypography.labelLarge).foregroundColor(FFColors.textPrimary)
                                    }
                                }.tint(FFColors.goldPrimary)

                                Divider().background(Color.white.opacity(0.1))

                                Toggle(isOn: $filters.includeNowPlaying) {
                                    HStack(spacing: FFSpacing.sm) {
                                        Image(systemName: "popcorn.fill").foregroundColor(FFColors.goldPrimary)
                                        Text("Include Now Playing").font(FFTypography.labelLarge).foregroundColor(FFColors.textPrimary)
                                    }
                                }.tint(FFColors.goldPrimary)

                                Divider().background(Color.white.opacity(0.1))

                                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                    HStack(spacing: FFSpacing.sm) {
                                        Image(systemName: "eye.slash.fill").foregroundColor(FFColors.textSecondary)
                                        Text("Watched Movies").font(FFTypography.labelLarge).foregroundColor(FFColors.textPrimary)
                                    }
                                    Picker("Exclude Watched", selection: $filters.excludeSeenMode) {
                                        ForEach(ExcludeSeenMode.allCases, id: \.self) { mode in
                                            Text(mode.displayName).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding()
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
                do {
                    genres = try await TMDBService.shared.getGenres()
                } catch {
                    genres = [
                        Genre(id: 28, name: "Action"), Genre(id: 12, name: "Adventure"),
                        Genre(id: 16, name: "Animation"), Genre(id: 35, name: "Comedy"),
                        Genre(id: 80, name: "Crime"), Genre(id: 18, name: "Drama"),
                        Genre(id: 14, name: "Fantasy"), Genre(id: 27, name: "Horror"),
                        Genre(id: 9648, name: "Mystery"), Genre(id: 10749, name: "Romance"),
                        Genre(id: 878, name: "Sci-Fi"), Genre(id: 53, name: "Thriller")
                    ]
                }
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

