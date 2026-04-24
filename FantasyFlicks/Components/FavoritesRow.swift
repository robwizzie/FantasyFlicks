//
//  FavoritesRow.swift
//  FantasyFlicks
//
//  A Letterboxd-style row of up to 4 pinned favorite movies. On your own
//  profile, empty slots show a + tile that opens an edit sheet. On someone
//  else's profile, empty slots are hidden.
//

import SwiftUI

struct FavoritesRow: View {
    /// TMDB IDs of the user's favorites. Displayed in order, capped at 4.
    let tmdbIds: [Int]
    /// When true, empty slots show a + tile and tapping opens the edit sheet.
    let isEditable: Bool
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
                        // Hidden for viewers — don't advertise empty slots.
                        Color.clear
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

    private func tile(for tmdbId: Int) -> some View {
        Button {
            if let cached = seenService.cachedMovie(for: tmdbId) {
                onTapMovie(cached.toFFMovie())
            }
        } label: {
            Group {
                if let posterURL = seenService.cachedMovie(for: tmdbId)?.posterURL {
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
}
