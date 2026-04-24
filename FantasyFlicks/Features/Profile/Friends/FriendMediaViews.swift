//
//  FriendMediaViews.swift
//  FantasyFlicks
//
//  Read-only views onto another user's Diary, Watched, Watchlist, and Ratings.
//  Driven by a FriendMediaSnapshot fetched from Firestore.
//

import SwiftUI

// MARK: - Friend Diary

struct FriendDiaryView: View {
    let user: FFUser
    let snapshot: FriendMediaSnapshot
    @Environment(\.dismiss) private var dismiss

    private var groupedEntries: [(String, [DiaryEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: snapshot.diary) { formatter.string(from: $0.watchedDate) }
        return grouped.sorted { $0.value.first!.watchedDate > $1.value.first!.watchedDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if snapshot.diary.isEmpty {
                    emptyState(
                        icon: "book.closed",
                        title: "No diary entries",
                        subtitle: "\(user.displayName) hasn't logged any movies yet"
                    )
                } else {
                    List {
                        ForEach(groupedEntries, id: \.0) { month, entries in
                            Section {
                                ForEach(entries) { entry in
                                    diaryRow(entry: entry)
                                        .listRowBackground(FFColors.backgroundElevated.opacity(0.3))
                                }
                            } header: {
                                Text(month)
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.goldPrimary)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("\(user.displayName)'s Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
    }

    private func diaryRow(entry: DiaryEntry) -> some View {
        HStack(spacing: FFSpacing.md) {
            posterThumb(url: entry.posterURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)

                Text(entry.watchedDate, style: .date)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)

                if let rating = entry.effectiveRating {
                    StarRatingDisplay(rating: rating, size: 10, dimColor: FFColors.textTertiary)
                }

                if let review = entry.reviewText, !review.isEmpty {
                    Text(review)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, FFSpacing.xs)
    }
}

// MARK: - Friend Watched

struct FriendWatchedView: View {
    let user: FFUser
    let snapshot: FriendMediaSnapshot
    @Environment(\.dismiss) private var dismiss

    private var items: [CachedMovie] {
        snapshot.seenIds.compactMap { snapshot.cachedMovie(for: $0) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if items.isEmpty {
                    emptyState(
                        icon: "eye.slash",
                        title: "Nothing watched",
                        subtitle: "\(user.displayName) hasn't marked any movies as watched"
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: FFSpacing.sm) {
                            header(count: items.count, label: "movies watched")
                            ForEach(items) { item in
                                movieRow(item: item, rating: snapshot.ratings[item.id])
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, FFSpacing.md)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("\(user.displayName)'s Watched")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
    }
}

// MARK: - Friend Watchlist

struct FriendWatchlistView: View {
    let user: FFUser
    let snapshot: FriendMediaSnapshot
    @Environment(\.dismiss) private var dismiss

    private var items: [CachedMovie] {
        snapshot.watchlistIds.compactMap { snapshot.cachedMovie(for: $0) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if items.isEmpty {
                    emptyState(
                        icon: "bookmark",
                        title: "Nothing saved",
                        subtitle: "\(user.displayName) hasn't added anything to their watchlist"
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: FFSpacing.sm) {
                            header(count: items.count, label: "on watchlist")
                            ForEach(items) { item in
                                movieRow(item: item, rating: nil)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, FFSpacing.md)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("\(user.displayName)'s Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
    }
}

// MARK: - Friend Ratings

struct FriendRatingsView: View {
    let user: FFUser
    let snapshot: FriendMediaSnapshot
    @Environment(\.dismiss) private var dismiss

    private var items: [(tmdbId: Int, stars: Double, cached: CachedMovie?)] {
        snapshot.ratings
            .map { (tmdbId: $0.key, stars: $0.value, cached: snapshot.cachedMovie(for: $0.key)) }
            .sorted {
                if $0.stars != $1.stars { return $0.stars > $1.stars }
                return ($0.cached?.title ?? "").localizedCaseInsensitiveCompare($1.cached?.title ?? "") == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if items.isEmpty {
                    emptyState(
                        icon: "star",
                        title: "No ratings",
                        subtitle: "\(user.displayName) hasn't rated any movies yet"
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: FFSpacing.sm) {
                            header(count: items.count, label: "rated")
                            ForEach(items, id: \.tmdbId) { item in
                                ratingRow(tmdbId: item.tmdbId, stars: item.stars, cached: item.cached)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, FFSpacing.md)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("\(user.displayName)'s Ratings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
        }
    }

    private func ratingRow(tmdbId: Int, stars: Double, cached: CachedMovie?) -> some View {
        HStack(spacing: FFSpacing.md) {
            posterThumb(url: cached?.posterURL)

            VStack(alignment: .leading, spacing: 6) {
                Text(cached?.title ?? "Loading…")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(2)

                if let year = cached?.year {
                    Text(String(year))
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }

                StarRatingDisplay(rating: stars, size: 12)
            }

            Spacer()
        }
        .padding(FFSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                .fill(FFColors.backgroundElevated.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Shared helpers

private func header(count: Int, label: String) -> some View {
    HStack {
        Text("\(count) \(label)")
            .font(FFTypography.labelSmall)
            .foregroundColor(FFColors.textTertiary)
        Spacer()
    }
    .padding(.horizontal, 4)
}

private func movieRow(item: CachedMovie, rating: Double?) -> some View {
    HStack(spacing: FFSpacing.md) {
        posterThumb(url: item.posterURL)

        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(FFTypography.labelMedium)
                .foregroundColor(FFColors.textPrimary)
                .lineLimit(2)

            HStack(spacing: FFSpacing.sm) {
                if let year = item.year {
                    Text(String(year))
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textTertiary)
                }
                if let vote = item.voteAverage, vote > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(FFColors.goldPrimary)
                        Text(String(format: "%.1f", vote))
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.goldLight)
                    }
                }
            }

            if let rating {
                StarRatingDisplay(rating: rating, size: 10)
            }
        }

        Spacer()
    }
    .padding(FFSpacing.md)
    .background {
        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
            .fill(FFColors.backgroundElevated.opacity(0.5))
            .overlay {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            }
    }
}

private func posterThumb(url: URL?) -> some View {
    Group {
        if let url {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(FFColors.backgroundElevated)
            }
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(FFColors.backgroundElevated)
                .overlay {
                    Image(systemName: "film")
                        .foregroundColor(FFColors.textTertiary)
                }
        }
    }
    .frame(width: 48, height: 72)
    .clipShape(RoundedRectangle(cornerRadius: 6))
}

private func emptyState(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: FFSpacing.lg) {
        Image(systemName: icon)
            .font(.system(size: 48))
            .foregroundColor(FFColors.textTertiary)
        Text(title)
            .font(FFTypography.titleMedium)
            .foregroundColor(FFColors.textSecondary)
        Text(subtitle)
            .font(FFTypography.bodySmall)
            .foregroundColor(FFColors.textTertiary)
            .multilineTextAlignment(.center)
    }
    .padding()
}
