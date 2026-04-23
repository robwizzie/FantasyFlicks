//
//  ReviewSheet.swift
//  FantasyFlicks
//
//  Log a movie with date, rating, and review text
//

import SwiftUI

struct ReviewSheet: View {
    let movie: FFMovie
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared
    @State private var rating: Int = 0
    @State private var watchedDate = Date()
    @State private var reviewText = ""

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

                        // Rating
                        GlassCard {
                            VStack(spacing: FFSpacing.md) {
                                Text("Your Rating")
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.textTertiary)

                                HStack(spacing: FFSpacing.sm) {
                                    ForEach(1...5, id: \.self) { star in
                                        Button {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                                rating = rating == star ? 0 : star
                                            }
                                        } label: {
                                            Image(systemName: star <= rating ? "star.fill" : "star")
                                                .font(.system(size: 28))
                                                .foregroundColor(star <= rating ? FFColors.goldPrimary : FFColors.textTertiary)
                                                .scaleEffect(star <= rating ? 1.1 : 1.0)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
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
                            seenService.addDiaryEntry(
                                tmdbId: movie.tmdbId,
                                title: movie.title,
                                posterPath: movie.posterPath,
                                watchedDate: watchedDate,
                                rating: rating > 0 ? rating : nil,
                                reviewText: reviewText.isEmpty ? nil : reviewText
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
            }
        }
    }
}
