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
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateDesc

    enum SortOption: String, CaseIterable {
        case dateDesc = "Newest first"
        case dateAsc = "Oldest first"
        case titleAsc = "Title (A–Z)"
        case ratingDesc = "Highest rated"
        case ratingAsc = "Lowest rated"
    }

    /// Filter by search text then sort. Grouping by month only applies for the
    /// default date sort — other sorts return a single flat section.
    private var filteredAndSorted: [DiaryEntry] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = q.isEmpty ? seenService.diary : seenService.diary.filter {
            $0.title.lowercased().contains(q) ||
            ($0.reviewText?.lowercased().contains(q) ?? false)
        }
        switch sortOption {
        case .dateDesc: return filtered.sorted { $0.watchedDate > $1.watchedDate }
        case .dateAsc: return filtered.sorted { $0.watchedDate < $1.watchedDate }
        case .titleAsc: return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .ratingDesc: return filtered.sorted { ($0.effectiveRating ?? -1) > ($1.effectiveRating ?? -1) }
        case .ratingAsc: return filtered.sorted { ($0.effectiveRating ?? 99) < ($1.effectiveRating ?? 99) }
        }
    }

    private var groupedEntries: [(String, [DiaryEntry])] {
        let entries = filteredAndSorted
        guard sortOption == .dateDesc || sortOption == .dateAsc else {
            return [("Results", entries)]
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let grouped = Dictionary(grouping: entries) { formatter.string(from: $0.watchedDate) }
        return grouped.sorted { lhs, rhs in
            let lhsDate = lhs.value.first!.watchedDate
            let rhsDate = rhs.value.first!.watchedDate
            return sortOption == .dateDesc ? lhsDate > rhsDate : lhsDate < rhsDate
        }
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
                        Section {
                            EmptyView()
                        } header: {
                            sortBar
                                .textCase(nil)
                                .listRowInsets(EdgeInsets())
                        }
                        .listRowBackground(Color.clear)

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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search titles or reviews")
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

    private var sortBar: some View {
        HStack {
            Text("\(filteredAndSorted.count) \(filteredAndSorted.count == 1 ? "entry" : "entries")")
                .font(FFTypography.caption)
                .foregroundColor(FFColors.textTertiary)
            Spacer()
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 10, weight: .bold))
                    Text(sortOption.rawValue).font(FFTypography.labelSmall)
                }
                .foregroundColor(FFColors.goldPrimary)
                .padding(.horizontal, FFSpacing.md)
                .padding(.vertical, 6)
                .background(FFColors.goldPrimary.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, FFSpacing.sm)
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
