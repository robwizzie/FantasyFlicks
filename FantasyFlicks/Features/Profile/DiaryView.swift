//
//  DiaryView.swift
//  FantasyFlicks
//
//  Chronological watch history like Letterboxd diary
//

import SwiftUI

struct DiaryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var seenService = SeenMoviesService.shared
    @State private var selectedMovie: FFMovie?

    private var groupedEntries: [(String, [DiaryEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: seenService.diary) { formatter.string(from: $0.watchedDate) }
        return grouped.sorted { $0.value.first!.watchedDate > $1.value.first!.watchedDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                if seenService.diary.isEmpty {
                    VStack(spacing: FFSpacing.lg) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(FFColors.textTertiary)
                        Text("No diary entries yet")
                            .font(FFTypography.titleMedium)
                            .foregroundColor(FFColors.textSecondary)
                        Text("Log movies from the Movies tab to start your diary")
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(groupedEntries, id: \.0) { month, entries in
                            Section {
                                ForEach(entries) { entry in
                                    Button {
                                        openMovie(for: entry)
                                    } label: {
                                        diaryRow(entry: entry)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(FFColors.backgroundElevated.opacity(0.3))
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        seenService.removeDiaryEntry(id: entries[index].id)
                                    }
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
            .navigationTitle("Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
            .sheet(item: $selectedMovie) { movie in
                NavigationStack { MovieDetailView(movie: movie) }
            }
        }
    }

    private func openMovie(for entry: DiaryEntry) {
        // Prefer a richer cached record if one exists; fall back to the entry itself.
        if let cached = seenService.cachedMovie(for: entry.tmdbId) {
            selectedMovie = cached.toFFMovie()
        } else {
            selectedMovie = FFMovie(
                tmdbId: entry.tmdbId,
                title: entry.title,
                posterPath: entry.posterPath
            )
        }
    }

    private func diaryRow(entry: DiaryEntry) -> some View {
        HStack(alignment: .top, spacing: FFSpacing.md) {
            // Poster — fall back to cached metadata if the entry itself has no path
            posterView(entry: entry)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(entry.title)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if entry.isRewatch {
                        Text("rewatch")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(FFColors.goldPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(FFColors.goldPrimary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(entry.watchedDate, style: .date)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)

                if let rating = entry.effectiveRating {
                    StarRatingDisplay(rating: rating, size: 10)
                }

                if let review = entry.reviewText, !review.isEmpty {
                    Text(review)
                        .font(FFTypography.caption)
                        .foregroundColor(FFColors.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, FFSpacing.xs)
    }

    private func posterView(entry: DiaryEntry) -> some View {
        Group {
            let posterURL = entry.posterURL ?? seenService.cachedMovie(for: entry.tmdbId)?.posterURL
            if let posterURL {
                CachedAsyncImage(url: posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    FFColors.backgroundElevated
                }
            } else {
                FFColors.backgroundElevated
                    .overlay {
                        Image(systemName: "film")
                            .foregroundColor(FFColors.textTertiary)
                    }
            }
        }
        .frame(width: 44, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
