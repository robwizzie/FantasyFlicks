//
//  ReviewSheet.swift
//  FantasyFlicks
//
//  Log a movie with date, rating, and review text
//

import SwiftUI

struct ReviewSheet: View {
    let movie: FFMovie
    /// If set, we're editing an existing diary entry (rewatch edit, etc.)
    var existingEntryId: String? = nil
    /// Defaults to `false`. If true, the saved entry is marked as a rewatch.
    var isRewatchDefault: Bool = false

    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared
    @State private var rating: Double = 0
    @State private var watchedDate = Date()
    @State private var reviewText = ""
    @State private var isRewatch = false

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FFSpacing.xl) {
                        // Movie header
                        HStack(spacing: FFSpacing.md) {
                            if let posterURL = movie.posterURL {
                                CachedAsyncImage(url: posterURL) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    FFColors.backgroundElevated
                                }
                                .frame(width: 60, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            VStack(alignment: .leading, spacing: FFSpacing.xs) {
                                Text(movie.title)
                                    .font(FFTypography.headlineSmall)
                                    .foregroundColor(FFColors.textPrimary)
                                    .lineLimit(2)

                                if let year = movie.year {
                                    Text(String(year))
                                        .font(FFTypography.labelSmall)
                                        .foregroundColor(FFColors.textSecondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal)

                        // Rating — Letterboxd-style half-stars
                        GlassCard {
                            VStack(spacing: FFSpacing.md) {
                                Text("Your Rating")
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.textTertiary)

                                HStack(spacing: FFSpacing.sm) {
                                    ForEach(1...5, id: \.self) { star in
                                        let starDouble = Double(star)
                                        let iconName: String = {
                                            if rating >= starDouble { return "star.fill" }
                                            if rating >= starDouble - 0.5 { return "star.leadinghalf.filled" }
                                            return "star"
                                        }()
                                        let filled = (rating >= starDouble - 0.5)

                                        Button {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                                if rating == starDouble {
                                                    rating = starDouble - 0.5
                                                } else if rating == starDouble - 0.5 {
                                                    rating = starDouble
                                                } else {
                                                    rating = starDouble
                                                }
                                                if rating < 0 { rating = 0 }
                                            }
                                        } label: {
                                            Image(systemName: iconName)
                                                .font(.system(size: 30))
                                                .foregroundColor(filled ? FFColors.goldPrimary : FFColors.textTertiary)
                                                .symbolRenderingMode(.hierarchical)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                if rating > 0 {
                                    Button("Clear rating") {
                                        withAnimation { rating = 0 }
                                    }
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Rewatch toggle
                        GlassCard {
                            Toggle(isOn: $isRewatch) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(FFColors.goldPrimary)
                                    Text("Rewatch")
                                        .font(FFTypography.labelMedium)
                                        .foregroundColor(FFColors.textPrimary)
                                }
                            }
                            .tint(FFColors.goldPrimary)
                        }
                        .padding(.horizontal)

                        // Date
                        GlassCard {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(FFColors.goldPrimary)
                                Text("Watched on")
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.textPrimary)
                                Spacer()
                                DatePicker("", selection: $watchedDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(FFColors.goldPrimary)
                                    .colorScheme(.dark)
                            }
                        }
                        .padding(.horizontal)

                        // Review text
                        GlassCard {
                            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                HStack {
                                    Text("Review")
                                        .font(FFTypography.labelMedium)
                                        .foregroundColor(FFColors.textTertiary)
                                    Spacer()
                                    Text("\(reviewText.count)/500")
                                        .font(FFTypography.caption)
                                        .foregroundColor(reviewText.count > 500 ? FFColors.ruby : FFColors.textTertiary)
                                }

                                TextEditor(text: $reviewText)
                                    .font(FFTypography.bodyMedium)
                                    .foregroundColor(FFColors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 100)
                                    .padding(FFSpacing.sm)
                                    .background(FFColors.backgroundDark.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                                    .onChange(of: reviewText) { _, newValue in
                                        if newValue.count > 500 {
                                            reviewText = String(newValue.prefix(500))
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)

                        // Log button
                        GoldButton(
                            title: "Log Movie",
                            icon: "checkmark.circle.fill",
                            style: .primary,
                            size: .large,
                            fullWidth: true
                        ) {
                            let starsToSave: Double? = rating > 0 ? rating : nil
                            seenService.addDiaryEntry(
                                tmdbId: movie.tmdbId,
                                title: movie.title,
                                posterPath: movie.posterPath,
                                watchedDate: watchedDate,
                                rating: starsToSave,
                                reviewText: reviewText.isEmpty ? nil : reviewText,
                                isRewatch: isRewatch
                            )
                            dismiss()
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 50)
                    }
                    .padding(.top, FFSpacing.lg)
                }
            }
            .navigationTitle("Log Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
            }
            .onAppear {
                // Pre-fill with existing rating if any
                if let existing = seenService.rating(for: movie.tmdbId) {
                    rating = existing
                }
                isRewatch = isRewatchDefault
            }
        }
    }
}
