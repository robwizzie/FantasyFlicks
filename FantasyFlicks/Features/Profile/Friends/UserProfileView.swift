//
//  UserProfileView.swift
//  FantasyFlicks
//
//  Read-only profile view for another user: header, stats, bio, and
//  a My Movies-style hub (Diary / Watched / Watchlist / Ratings) that
//  respects the friend's privacy settings.
//

import SwiftUI

struct UserProfileView: View {
    let user: FFUser

    @StateObject private var friendsService = FriendsService.shared
    @State private var isWorking = false
    @State private var snapshot: FriendMediaSnapshot = .empty
    @State private var isLoadingMedia = true

    @State private var showDiary = false
    @State private var showWatched = false
    @State private var showWatchlist = false
    @State private var showRatings = false
    @State private var favoriteDetail: FFMovie?

    private var isFriend: Bool {
        friendsService.isFriend(user.id)
    }

    // Privacy gates: must be a friend AND the list must not be private.
    private var canSeeDiary: Bool { isFriend && !user.diaryPrivate }
    private var canSeeWatched: Bool { isFriend && !user.watchedPrivate }
    private var canSeeWatchlist: Bool { isFriend && !user.watchlistPrivate }
    private var canSeeRatings: Bool { isFriend && !user.ratingsPrivate }

    var body: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: FFSpacing.xl) {
                    header

                    // Always render the Top 4 section — even with no favorites
                    // it shows four placeholder slots so the layout stays
                    // consistent and the user knows this is where favorites live.
                    FavoritesRow(
                        tmdbIds: user.favoriteMovieIds,
                        isEditable: false,
                        posterOverrides: snapshot.favoritePosterOverrides,
                        onTapMovie: { favoriteDetail = $0 },
                        onEdit: {}
                    )

                    if let bio = user.bio, !bio.isEmpty {
                        bioSection(bio)
                    }

                    moviesHubSection

                    Spacer(minLength: 60)
                }
                .padding(.top, FFSpacing.md)
            }
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if isFriend {
                        Button(role: .destructive) {
                            Task { await removeFriend() }
                        } label: {
                            Label("Remove Friend", systemImage: "person.badge.minus")
                        }
                    }
                    Button(role: .destructive) {
                        Task { await block() }
                    } label: {
                        Label("Block User", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
        .task {
            await loadSnapshot()
        }
        .sheet(isPresented: $showDiary) {
            FriendDiaryView(user: user, snapshot: snapshot)
        }
        .sheet(isPresented: $showWatched) {
            FriendWatchedView(user: user, snapshot: snapshot)
        }
        .sheet(isPresented: $showWatchlist) {
            FriendWatchlistView(user: user, snapshot: snapshot)
        }
        .sheet(isPresented: $showRatings) {
            FriendRatingsView(user: user, snapshot: snapshot)
        }
        .sheet(item: $favoriteDetail) { movie in
            NavigationStack {
                MovieDetailView(movie: movie)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        GlassCard(goldTint: true) {
            HStack(spacing: FFSpacing.lg) {
                AvatarView(user: user, size: 80)

                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text(user.displayName)
                        .font(FFTypography.headlineMedium)
                        .foregroundColor(FFColors.textPrimary)

                    Text("@\(user.username)")
                        .font(FFTypography.bodyMedium)
                        .foregroundColor(FFColors.textSecondary)

                    if let genre = user.favoriteGenre {
                        HStack(spacing: FFSpacing.xs) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(FFColors.ruby)
                            Text(genre)
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal)
        .overlay(alignment: .bottom) {
            friendActionButton
                .offset(y: 22)
                .padding(.bottom, -22)
        }
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private var friendActionButton: some View {
        if isFriend {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Friends")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(FFColors.success)
            .padding(.horizontal, FFSpacing.lg)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(FFColors.success.opacity(0.5), lineWidth: 1)
            }
        } else {
            Button {
                Task { await addFriend() }
            } label: {
                HStack(spacing: 4) {
                    if isWorking {
                        InlineLoader(tint: FFColors.backgroundDark, size: 14)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text("Add Friend")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(FFColors.backgroundDark)
                .padding(.horizontal, FFSpacing.lg)
                .padding(.vertical, 8)
                .background(FFColors.goldGradient)
                .clipShape(Capsule())
                .shadow(color: FFColors.goldPrimary.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text("Stats")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)
                .padding(.horizontal)

            HStack(spacing: FFSpacing.md) {
                StatCard(value: "\(user.totalLeagues)", label: "Leagues", icon: "trophy.fill")
                StatCard(value: "\(user.leaguesWon)", label: "Wins", icon: "crown.fill")
                StatCard(value: user.winRatePercentage, label: "Win Rate", icon: "chart.line.uptrend.xyaxis")
                StatCard(value: "\(user.totalMoviesDrafted)", label: "Drafted", icon: "film.fill")
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Bio

    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            Text("About")
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)

            GlassCard {
                Text(bio)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Movies Hub

    private var moviesHubSection: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            HStack {
                Text("Movies")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)

                Spacer()

                if isLoadingMedia {
                    InlineLoader(size: 14)
                }
            }
            .padding(.horizontal)

            if !isFriend {
                notFriendsCard
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FFSpacing.md) {
                    hubCard(
                        icon: "book.closed.fill",
                        title: "Diary",
                        count: snapshot.diary.count,
                        color: FFColors.goldPrimary,
                        isPrivate: user.diaryPrivate,
                        canView: canSeeDiary
                    ) { showDiary = true }

                    hubCard(
                        icon: "eye.fill",
                        title: "Watched",
                        count: snapshot.seenIds.count,
                        color: FFColors.success,
                        isPrivate: user.watchedPrivate,
                        canView: canSeeWatched
                    ) { showWatched = true }

                    hubCard(
                        icon: "bookmark.fill",
                        title: "Watchlist",
                        count: snapshot.watchlistIds.count,
                        color: FFColors.ruby,
                        isPrivate: user.watchlistPrivate,
                        canView: canSeeWatchlist
                    ) { showWatchlist = true }

                    hubCard(
                        icon: "star.fill",
                        title: "Ratings",
                        count: snapshot.ratings.count,
                        color: FFColors.goldLight,
                        isPrivate: user.ratingsPrivate,
                        canView: canSeeRatings
                    ) { showRatings = true }
                }
                .padding(.horizontal)
            }
        }
    }

    private var notFriendsCard: some View {
        VStack(spacing: FFSpacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundColor(FFColors.textTertiary)
            Text("Add \(user.displayName) as a friend")
                .font(FFTypography.titleSmall)
                .foregroundColor(FFColors.textSecondary)
            Text("You'll be able to see their diary, watched list, watchlist, and ratings.")
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FFSpacing.xxl)
        .padding(.horizontal, FFSpacing.xl)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.large)
                .fill(FFColors.backgroundElevated.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                }
        }
        .padding(.horizontal)
    }

    private func hubCard(
        icon: String,
        title: String,
        count: Int,
        color: Color,
        isPrivate: Bool,
        canView: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: canView ? action : {}) {
            VStack(spacing: FFSpacing.sm) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(canView ? color : FFColors.textTertiary)
                        .opacity(canView ? 1 : 0.4)

                    if isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(FFColors.textTertiary)
                            .offset(x: 14, y: -14)
                    }
                }

                Text(canView ? "\(count)" : "—")
                    .font(FFTypography.titleMedium)
                    .foregroundColor(canView ? FFColors.textPrimary : FFColors.textTertiary)

                Text(canView ? title : (isPrivate ? "Private" : title))
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FFSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .fill(FFColors.backgroundElevated.opacity(canView ? 0.6 : 0.3))
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
            }
            .opacity(canView ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!canView)
    }

    // MARK: - Actions

    private func loadSnapshot() async {
        isLoadingMedia = true
        defer { isLoadingMedia = false }
        do {
            snapshot = try await FriendMediaService.shared.fetchMediaSnapshot(for: user.id)
        } catch {
            snapshot = .empty
        }
    }

    private func addFriend() async {
        isWorking = true
        defer { isWorking = false }
        try? await friendsService.addFriend(user)
        // Now that we're friends, load the media snapshot
        await loadSnapshot()
    }

    private func removeFriend() async {
        try? await friendsService.removeFriend(userId: user.id)
    }

    private func block() async {
        try? await friendsService.blockUser(user.id)
    }
}
