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
    @State private var selectedMovie: FFMovie?
    @State private var showLetterboxdConnect = false

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

    // MARK: - List

    private var recommendationsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: FFSpacing.md) {
                tasteSummary

                ForEach(engine.recommendations) { recommendation in
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

                if engine.isLoading {
                    InlineLoader(size: 20)
                        .padding(.vertical, FFSpacing.lg)
                }

                Spacer(minLength: 100)
            }
            .padding(.top, FFSpacing.md)
        }
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
        return String(format: "From %d rated films · you average %.1f★", count, engine.profile.meanRating)
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

                if engine.recommendations.isEmpty {
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
                            ForEach(engine.recommendations.prefix(12)) { recommendation in
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
