//
//  ForYouView.swift
//  FantasyFlicks
//
//  Personalised recommendations built from the user's own ratings, with the
//  reasoning shown on every card.
//

import SwiftUI

// MARK: - Full Screen

struct ForYouView: View {
    @StateObject private var engine = RecommendationEngine.shared
    @StateObject private var letterboxd = LetterboxdService.shared
    /// Observed so the "hide watchlisted" filter re-applies the moment a card's
    /// bookmark is tapped — `visibleRecommendations` reads the watchlist, and
    /// without a subscription here the list would go stale until something else
    /// forced a redraw.
    @StateObject private var seenService = SeenMoviesService.shared
    @State private var selectedMovie: FFMovie?
    @State private var showLetterboxdConnect = false
    @State private var showFilters = false

    private var visible: [MovieRecommendation] { engine.visibleRecommendations }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            if !engine.hasEnoughData {
                notEnoughDataState
            } else if engine.recommendations.isEmpty && engine.isLoading {
                loadingState
            } else if engine.recommendations.isEmpty {
                emptyState
            } else {
                recommendationsList
            }
        }
        .navigationTitle("For You")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !engine.recommendations.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
                ToolbarItem(placement: .topBarTrailing) { filterButton }
            }
            if !engine.dismissedIds.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            engine.clearDismissed()
                            Task { await engine.rebuild() }
                        } label: {
                            Label("Restore \(engine.dismissedIds.count) hidden", systemImage: "arrow.uturn.backward")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(FFColors.goldPrimary)
                    }
                }
            }
        }
        .task {
            await engine.refreshIfNeeded()
        }
        .refreshable {
            await engine.rebuild()
        }
        .sheet(item: $selectedMovie) { movie in
            NavigationStack { MovieDetailView(movie: movie) }
        }
        .sheet(isPresented: $showFilters) {
            RecommendationFilterSheet(engine: engine)
        }
        .sheet(isPresented: $showLetterboxdConnect) {
            LetterboxdConnectSheet()
        }
        .onChange(of: showLetterboxdConnect) { _, isShowing in
            // A finished import can push the user over the ratings threshold —
            // rebuild as soon as they close the sheet.
            guard !isShowing, engine.hasEnoughData else { return }
            Task { await engine.rebuild() }
        }
    }

    // MARK: - Toolbar

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $engine.sort) {
                ForEach(RecommendationSort.allCases) { option in
                    Label(option.displayName, systemImage: option.iconName).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundColor(FFColors.goldPrimary)
        }
        .accessibilityLabel("Sort recommendations")
    }

    private var filterButton: some View {
        Button {
            showFilters = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: engine.filter.isActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .foregroundColor(FFColors.goldPrimary)

                if engine.filter.activeCount > 0 {
                    Text("\(engine.filter.activeCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(FFColors.backgroundDark)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(FFColors.goldPrimary))
                        .offset(x: 7, y: -6)
                }
            }
        }
        .accessibilityLabel("Filter recommendations")
    }

    // MARK: - List

    private var recommendationsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: FFSpacing.md) {
                tasteSummary

                if engine.filter.isActive {
                    activeFilterBar
                }

                if visible.isEmpty {
                    noMatchesState
                } else {
                    ForEach(visible) { recommendation in
                        RecommendationCard(
                            recommendation: recommendation,
                            onTap: { selectedMovie = recommendation.movie },
                            onDismiss: {
                                withAnimation(FFAnimations.smooth) {
                                    engine.dismiss(tmdbId: recommendation.movie.tmdbId)
                                }
                            }
                        )
                        .padding(.horizontal)
                    }
                }

                if engine.isLoading {
                    InlineLoader(size: 20)
                        .padding(.vertical, FFSpacing.lg)
                }

                Spacer(minLength: 100)
            }
            .padding(.top, FFSpacing.md)
            .animation(FFAnimations.smooth, value: engine.filter)
            .animation(FFAnimations.smooth, value: engine.sort)
        }
    }

    private var activeFilterBar: some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(FFColors.goldPrimary)

            Text("\(visible.count) of \(engine.availableRecommendations.count)")
                .font(FFTypography.labelSmall)
                .foregroundColor(FFColors.textSecondary)

            Spacer(minLength: 0)

            Button {
                withAnimation(FFAnimations.smooth) { engine.resetFilter() }
            } label: {
                Text("Clear")
                    .font(FFTypography.labelSmall)
                    .foregroundColor(FFColors.goldPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FFSpacing.md)
        .padding(.vertical, FFSpacing.sm)
        .background(FFColors.goldPrimary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
        .padding(.horizontal)
    }

    /// Two genuinely different empty states share this slot: filters that are
    /// too narrow, and a shelf the user has worked all the way through. Telling
    /// someone to widen filters they never set would be nonsense.
    @ViewBuilder
    private var noMatchesState: some View {
        if engine.filter.isActive {
            emptyStateBody(
                icon: "line.3.horizontal.decrease.circle",
                title: "Nothing matches those filters",
                message: "Your \(engine.availableRecommendations.count) picks are still there — widen the filters to see them.",
                actionTitle: "Clear Filters",
                actionIcon: "arrow.uturn.backward"
            ) {
                withAnimation(FFAnimations.smooth) { engine.resetFilter() }
            }
        } else {
            emptyStateBody(
                icon: "checkmark.circle",
                title: "You're all caught up",
                message: "You've watched or passed on everything we picked. Build a fresh set from your latest ratings.",
                actionTitle: "Find More",
                actionIcon: "sparkles"
            ) {
                Task { await engine.rebuild() }
            }
        }
    }

    private func emptyStateBody(
        icon: String,
        title: String,
        message: String,
        actionTitle: String,
        actionIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: FFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(FFColors.textTertiary)

            Text(title)
                .font(FFTypography.titleSmall)
                .foregroundColor(FFColors.textPrimary)

            Text(message)
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            GoldButton(title: actionTitle, icon: actionIcon, style: .secondary, size: .small, action: action)
        }
        .padding(FFSpacing.xl)
        .frame(maxWidth: .infinity)
    }

    private var tasteSummary: some View {
        GlassCard(goldTint: true) {
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                HStack(spacing: FFSpacing.md) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 20))
                        .foregroundColor(FFColors.goldPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tuned to your ratings")
                            .font(FFTypography.titleSmall)
                            .foregroundColor(FFColors.textPrimary)
                        Text(summaryText)
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }

                    Spacer(minLength: 0)
                }

                if !topGenreNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FFSpacing.sm) {
                            ForEach(topGenreNames, id: \.self) { name in
                                Text(name)
                                    .font(FFTypography.labelSmall)
                                    .foregroundColor(FFColors.goldPrimary)
                                    .padding(.horizontal, FFSpacing.md)
                                    .padding(.vertical, 6)
                                    .background(FFColors.goldPrimary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, FFSpacing.sm)
    }

    private var summaryText: String {
        let count = engine.profile.ratedCount
        guard count > 0 else { return "Rate a few films to sharpen this" }
        let base = String(format: "From %d rated films · you average %.1f★", count, engine.profile.meanRating)
        guard engine.neighbourCount > 0 else { return base }
        return base + " · \(engine.neighbourCount) taste \(engine.neighbourCount == 1 ? "match" : "matches")"
    }

    private var topGenreNames: [String] {
        engine.profile.topGenreIds
            .prefix(4)
            .compactMap { engine.profile.genreNames[$0] }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: FFSpacing.lg) {
            InlineLoader(size: 28)
            Text("Reading your taste…")
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notEnoughDataState: some View {
        VStack(spacing: FFSpacing.lg) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundColor(FFColors.goldPrimary.opacity(0.5))

            VStack(spacing: FFSpacing.sm) {
                Text("Rate \(engine.ratingsNeeded) more \(engine.ratingsNeeded == 1 ? "film" : "films")")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Text("Recommendations get built from what you rate highly. The fastest way to fill this in is to connect Letterboxd.")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !letterboxd.isConnected {
                Button {
                    showLetterboxdConnect = true
                } label: {
                    Text("Connect Letterboxd")
                        .font(FFTypography.labelLarge)
                        .foregroundColor(FFColors.backgroundDark)
                        .padding(.horizontal, FFSpacing.xl)
                        .frame(height: 48)
                        .background(FFColors.goldGradientHorizontal)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FFSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: FFSpacing.lg) {
            Image(systemName: "film.stack")
                .font(.system(size: 44))
                .foregroundColor(FFColors.textTertiary)

            Text(engine.error ?? "No recommendations right now")
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            GoldButton(title: "Try Again", icon: "arrow.clockwise", style: .secondary, size: .medium) {
                Task { await engine.rebuild() }
            }
        }
        .padding(FFSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Sheet

/// Binds straight to the engine's published filter rather than editing a draft.
/// Everything is client-side over an already-built set, so each control gives
/// immediate feedback and the live result count stays honest while you drag.
struct RecommendationFilterSheet: View {
    @ObservedObject var engine: RecommendationEngine
    @Environment(\.dismiss) private var dismiss

    private var yearRange: ClosedRange<Int>? { engine.availableYearRange }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.lg) {
                        reasonSection
                        genreSection
                        if yearRange != nil { yearSection }
                        qualitySection

                        GlassCard {
                            Toggle(isOn: $engine.filter.hideWatchlisted) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hide Watchlisted")
                                        .font(FFTypography.labelLarge)
                                        .foregroundColor(FFColors.textPrimary)
                                    Text("Skip films you've already saved.")
                                        .font(FFTypography.caption)
                                        .foregroundColor(FFColors.textTertiary)
                                }
                            }
                            .tint(FFColors.goldPrimary)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal)
                    .padding(.top, FFSpacing.md)
                }

                VStack {
                    Spacer()
                    GoldButton(
                        title: resultsLabel,
                        icon: "checkmark",
                        style: .primary,
                        size: .medium,
                        fullWidth: true
                    ) { dismiss() }
                    .padding(.horizontal)
                    .padding(.bottom, FFSpacing.md)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { engine.resetFilter() }
                        .foregroundColor(engine.filter.isActive ? FFColors.ruby : FFColors.textTertiary)
                        .disabled(!engine.filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
    }

    private var resultsLabel: String {
        let count = engine.visibleRecommendations.count
        guard count > 0 else { return "No matches" }
        return "Show \(count) \(count == 1 ? "film" : "films")"
    }

    // MARK: - Sections

    private var reasonSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                sectionHeader("sparkles", "Why It Was Picked")
                Text("Keep only the picks backed by the kind of evidence you trust.")
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: FFSpacing.sm) {
                    ForEach(RecommendationReason.Kind.allCases, id: \.self) { kind in
                        toggleChip(
                            label: kind.displayName,
                            icon: kind.iconName,
                            isOn: engine.filter.reasonKinds.contains(kind)
                        ) {
                            toggle(kind, in: &engine.filter.reasonKinds)
                        }
                    }
                }
            }
        }
    }

    private var genreSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                sectionHeader("theatermasks.fill", "Genres")

                let genres = engine.availableGenres
                if genres.isEmpty {
                    Text("No genre data on this set yet.")
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                } else {
                    FlowLayout(spacing: FFSpacing.sm) {
                        ForEach(genres, id: \.id) { genre in
                            toggleChip(
                                label: genre.name,
                                icon: nil,
                                isOn: engine.filter.genreIds.contains(genre.id)
                            ) {
                                toggle(genre.id, in: &engine.filter.genreIds)
                            }
                        }
                    }
                }
            }
        }
    }

    private var yearSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                guardedYearContent
            }
        }
    }

    @ViewBuilder
    private var guardedYearContent: some View {
        if let range = yearRange {
            let low = Double(range.lowerBound)
            let high = Double(range.upperBound)

            HStack {
                sectionHeader("calendar", "Release Years")
                Spacer()
                // `String(_:)` on each bound, not raw interpolation: a `Text`
                // built from a literal is a LocalizedStringKey, so an
                // interpolated Int gets the locale's grouping separator and
                // 1942 renders as "1,942".
                Text(String(engine.filter.minimumYear ?? range.lowerBound)
                     + "–"
                     + String(engine.filter.maximumYear ?? range.upperBound))
                    .font(FFTypography.statSmall)
                    .foregroundColor(FFColors.goldPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("From").font(FFTypography.caption).foregroundColor(FFColors.textTertiary)
                Slider(
                    value: Binding(
                        get: { Double(engine.filter.minimumYear ?? range.lowerBound) },
                        set: { newValue in
                            let year = Int(newValue.rounded())
                            engine.filter.minimumYear = year <= range.lowerBound ? nil : year
                            if let maximum = engine.filter.maximumYear, maximum < year {
                                engine.filter.maximumYear = year
                            }
                        }
                    ),
                    in: low...high,
                    step: 1
                )
                .tint(FFColors.goldPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("To").font(FFTypography.caption).foregroundColor(FFColors.textTertiary)
                Slider(
                    value: Binding(
                        get: { Double(engine.filter.maximumYear ?? range.upperBound) },
                        set: { newValue in
                            let year = Int(newValue.rounded())
                            engine.filter.maximumYear = year >= range.upperBound ? nil : year
                            if let minimum = engine.filter.minimumYear, minimum > year {
                                engine.filter.minimumYear = year
                            }
                        }
                    ),
                    in: low...high,
                    step: 1
                )
                .tint(FFColors.goldPrimary)
            }
        }
    }

    private var qualitySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                HStack {
                    sectionHeader("star.fill", "Minimum TMDB Rating")
                    Spacer()
                    Text(engine.filter.minimumTMDBRating > 0
                         ? String(format: "%.1f+", engine.filter.minimumTMDBRating)
                         : "Any")
                        .font(FFTypography.statSmall)
                        .foregroundColor(FFColors.goldPrimary)
                }
                Slider(value: $engine.filter.minimumTMDBRating, in: 0...9, step: 0.5)
                    .tint(FFColors.goldPrimary)

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    sectionHeader("wand.and.stars", "Minimum Match")
                    Spacer()
                    Text(engine.filter.minimumMatchScore > 0 ? "\(engine.filter.minimumMatchScore)%+" : "Any")
                        .font(FFTypography.statSmall)
                        .foregroundColor(FFColors.goldPrimary)
                }
                Slider(
                    value: Binding(
                        get: { Double(engine.filter.minimumMatchScore) },
                        set: { engine.filter.minimumMatchScore = Int($0.rounded()) }
                    ),
                    in: 0...95,
                    step: 5
                )
                .tint(FFColors.goldPrimary)
            }
        }
    }

    // MARK: - Building Blocks

    private func sectionHeader(_ icon: String, _ title: String) -> some View {
        HStack(spacing: FFSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(FFColors.goldPrimary)
            Text(title)
                .font(FFTypography.titleSmall)
                .foregroundColor(FFColors.textPrimary)
        }
    }

    private func toggleChip(label: String, icon: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 10))
                }
                Text(label)
                    .font(FFTypography.labelSmall)
                    .lineLimit(1)
            }
            .foregroundColor(isOn ? FFColors.backgroundDark : FFColors.goldPrimary)
            .padding(.horizontal, FFSpacing.md)
            .padding(.vertical, 7)
            .background {
                if isOn {
                    Capsule().fill(FFColors.goldPrimary)
                } else {
                    Capsule().stroke(FFColors.goldPrimary.opacity(0.4), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

// MARK: - Card

struct RecommendationCard: View {
    let recommendation: MovieRecommendation
    var onTap: () -> Void
    var onDismiss: () -> Void

    @StateObject private var seenService = SeenMoviesService.shared

    private var movie: FFMovie { recommendation.movie }
    private var isOnWatchlist: Bool { seenService.isOnWatchlist(tmdbId: movie.tmdbId) }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: FFSpacing.md) {
                poster

                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    header
                    reasons
                    Spacer(minLength: 0)
                    actions
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(FFSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .fill(FFColors.backgroundElevated.opacity(0.6))
            }
            .overlay {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var poster: some View {
        CachedAsyncImage(url: movie.posterURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                FFColors.backgroundElevated2
                Image(systemName: "film")
                    .foregroundColor(FFColors.textTertiary)
            }
        }
        .frame(width: 76, height: 114)
        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: FFSpacing.sm) {
                Text(movie.title)
                    .font(FFTypography.titleSmall)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                matchBadge
            }

            HStack(spacing: FFSpacing.sm) {
                if let year = movie.year {
                    Text(String(year))
                }
                if movie.voteAverage > 0 {
                    Text("·")
                    Label(String(format: "%.1f", movie.voteAverage), systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                }
                if let predicted = recommendation.predictedRating {
                    Text("·")
                    Text(String(format: "%.1f★ for you", predicted))
                        .foregroundColor(FFColors.goldLight)
                }
            }
            .font(FFTypography.caption)
            .foregroundColor(FFColors.textTertiary)
        }
    }

    private var matchBadge: some View {
        Text("\(recommendation.matchScore)%")
            .font(FFTypography.labelSmall)
            .foregroundColor(FFColors.goldPrimary)
            .padding(.horizontal, FFSpacing.sm)
            .padding(.vertical, 3)
            .background(FFColors.goldPrimary.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("\(recommendation.matchScore) percent match")
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(recommendation.reasons.prefix(2)) { reason in
                HStack(spacing: 5) {
                    Image(systemName: reason.iconName)
                        .font(.system(size: 9))
                        .foregroundColor(FFColors.goldPrimary.opacity(0.8))
                    Text(reason.text)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: FFSpacing.sm) {
            Button {
                seenService.toggleWatchlist(movie)
            } label: {
                Label(
                    isOnWatchlist ? "On Watchlist" : "Watchlist",
                    systemImage: isOnWatchlist ? "bookmark.fill" : "bookmark"
                )
                .font(FFTypography.labelSmall)
                .foregroundColor(isOnWatchlist ? FFColors.backgroundDark : FFColors.goldPrimary)
                .padding(.horizontal, FFSpacing.md)
                .padding(.vertical, 6)
                .background {
                    if isOnWatchlist {
                        Capsule().fill(FFColors.goldPrimary)
                    } else {
                        Capsule().stroke(FFColors.goldPrimary.opacity(0.5), lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(FFColors.textTertiary)
                    .padding(7)
                    .background(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Not interested in \(movie.title)")

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Compact Carousel

/// Horizontal "For You" strip for embedding in Movies and Home.
struct ForYouRow: View {
    @StateObject private var engine = RecommendationEngine.shared
    var onSelect: (FFMovie) -> Void
    var onSeeAll: () -> Void

    var body: some View {
        if engine.hasEnoughData {
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("For You")
                            .font(FFTypography.headlineSmall)
                            .foregroundColor(FFColors.textPrimary)
                        Text("Picked from what you rate highly")
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }

                    Spacer()

                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text("See All")
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                        }
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.goldPrimary)
                    }
                }
                .padding(.horizontal)

                if engine.availableRecommendations.isEmpty {
                    HStack(spacing: FFSpacing.md) {
                        if engine.isLoading {
                            InlineLoader(size: 16)
                            Text("Building your picks…")
                        } else {
                            Text("Pull to refresh your picks")
                        }
                    }
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: FFSpacing.md) {
                            ForEach(engine.availableRecommendations.prefix(12)) { recommendation in
                                ForYouPoster(recommendation: recommendation) {
                                    onSelect(recommendation.movie)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .task {
                await engine.refreshIfNeeded()
            }
        }
    }
}

private struct ForYouPoster: View {
    let recommendation: MovieRecommendation
    var onTap: () -> Void

    var body: some View {
        ScrollSafeButton(action: onTap) {
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(url: recommendation.movie.posterURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            FFColors.backgroundElevated2
                            Image(systemName: "film").foregroundColor(FFColors.textTertiary)
                        }
                    }
                    .frame(width: 130, height: 195)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))

                    Text("\(recommendation.matchScore)%")
                        .font(FFTypography.labelSmall)
                        .foregroundColor(FFColors.backgroundDark)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(FFColors.goldPrimary))
                        .padding(FFSpacing.sm)
                }

                Text(recommendation.movie.title)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)

                if let reason = recommendation.headlineReason {
                    Text(reason.text)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 130, alignment: .leading)
        }
    }
}
