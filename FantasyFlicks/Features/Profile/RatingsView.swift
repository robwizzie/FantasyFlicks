//
//  RatingsView.swift
//  FantasyFlicks
//
//  All rated movies with inline editing
//

import SwiftUI

struct RatingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared

    private var ratedMovies: [(tmdbId: Int, stars: Int)] {
        seenService.ratings.sorted { $0.value > $1.value }.map { (tmdbId: $0.key, stars: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if ratedMovies.isEmpty {
                    VStack(spacing: FFSpacing.lg) {
                        Image(systemName: "star")
                            .font(.system(size: 48))
                            .foregroundColor(FFColors.textTertiary)
                        Text("No ratings yet")
                            .font(FFTypography.titleMedium)
                            .foregroundColor(FFColors.textSecondary)
                        Text("Rate movies from the detail view or while swiping")
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: FFSpacing.sm) {
                            ForEach(ratedMovies, id: \.tmdbId) { item in
                                HStack(spacing: FFSpacing.md) {
                                    // Find title from diary if available
                                    let diaryEntry = seenService.diary.first { $0.tmdbId == item.tmdbId }

                                    if let posterURL = diaryEntry?.posterURL {
                                        CachedAsyncImage(url: posterURL) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: { FFColors.backgroundElevated }
                                        .frame(width: 40, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(FFColors.backgroundElevated)
                                            .frame(width: 40, height: 60)
                                            .overlay {
                                                Image(systemName: "film")
                                                    .foregroundColor(FFColors.textTertiary)
                                            }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(diaryEntry?.title ?? "Movie #\(item.tmdbId)")
                                            .font(FFTypography.labelMedium)
                                            .foregroundColor(FFColors.textPrimary)
                                            .lineLimit(1)

                                        StarRatingView(tmdbId: item.tmdbId, compact: false)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, FFSpacing.xs)
                            }
                        }
                        .padding(.top, FFSpacing.md)
                    }
                }
            }
            .navigationTitle("Ratings")
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
