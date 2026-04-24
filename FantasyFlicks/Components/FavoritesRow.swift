//
//  FavoritesRow.swift
//  FantasyFlicks
//
//  A Letterboxd-style row of up to 4 pinned favorite movies. Always renders
//  all 4 slots so a friend's profile still shows where their Top 4 would be,
//  even when they haven't pinned any. Respects user-picked alt posters.
//

import SwiftUI

struct FavoritesRow: View {
    /// TMDB IDs of the user's favorites. Displayed in order, capped at 4.
    let tmdbIds: [Int]
    /// When true, empty slots show a + tile and tapping opens the edit sheet.
    let isEditable: Bool
    /// Optional poster-path override map (used on friend profiles to honor the
    /// friend's own alt-poster picks). When nil, falls back to the local
    /// SeenMoviesService override store (i.e. the current user's own picks).
    var posterOverrides: [Int: String]? = nil
    /// Callback fired when any populated tile is tapped — hand off to a detail view.
    let onTapMovie: (FFMovie) -> Void
    /// Callback fired when the edit (+) tile is tapped — host should present an editor.
    let onEdit: () -> Void

    @StateObject private var seenService = SeenMoviesService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.sm) {
            HStack {
                Text("Favorites")
                    .font(FFTypography.headlineSmall)
                    .foregroundColor(FFColors.textPrimary)
                Spacer()
                if isEditable {
                    Button {
                        onEdit()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Edit")
                                .font(FFTypography.labelSmall)
                        }
                        .foregroundColor(FFColors.goldPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            HStack(spacing: FFSpacing.sm) {
                ForEach(0..<4, id: \.self) { slot in
                    if slot < tmdbIds.count {
                        tile(for: tmdbIds[slot])
                    } else if isEditable {
                        emptySlot
                    } else {
                        // Viewer sees a subtle placeholder so the Top 4 section
                        // is always visible, even when the friend hasn't pinned any.
                        viewerPlaceholderSlot
                    }
                }
            }
            .padding(.horizontal)
        }
        .task {
            // Make sure all favorites have cached metadata so posters render.
            await seenService.hydrateMissingMetadata(tmdbIds: Set(tmdbIds), limit: 4)
        }
    }

    /// Resolve the active poster URL for a favorite: explicit override (for
    /// viewing someone else's picks), local override store (your own picks),
    /// or the default cached poster.
    private func posterURL(for tmdbId: Int) -> URL? {
        if let overridePath = posterOverrides?[tmdbId] {
            return URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.PosterSize.medium.rawValue)\(overridePath)")
        }
        return seenService.favoritePosterURL(for: tmdbId)
    }

    private func tile(for tmdbId: Int) -> some View {
        Button {
            if let cached = seenService.cachedMovie(for: tmdbId) {
                onTapMovie(cached.toFFMovie())
            }
        } label: {
            Group {
                if let posterURL = posterURL(for: tmdbId) {
                    CachedAsyncImage(url: posterURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(FFColors.backgroundElevated)
                            .shimmer()
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FFColors.backgroundElevated)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundColor(FFColors.textTertiary)
                        }
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptySlot: some View {
        Button(action: onEdit) {
            RoundedRectangle(cornerRadius: 8)
                .fill(FFColors.backgroundElevated.opacity(0.4))
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(FFColors.textTertiary)
                        Text("Add")
                            .font(.system(size: 10))
                            .foregroundColor(FFColors.textTertiary)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            style: StrokeStyle(lineWidth: 1, dash: [4])
                        )
                        .foregroundColor(FFColors.textTertiary.opacity(0.4))
                }
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var viewerPlaceholderSlot: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(FFColors.backgroundElevated.opacity(0.25))
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 16))
                    .foregroundColor(FFColors.textTertiary.opacity(0.5))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(FFColors.textTertiary.opacity(0.15), lineWidth: 0.5)
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }
}
