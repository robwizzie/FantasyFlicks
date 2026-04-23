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
                                    diaryRow(entry: entry)
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
        }
    }

    private func diaryRow(entry: DiaryEntry) -> some View {
        HStack(spacing: FFSpacing.md) {
            // Poster
            if let posterURL = entry.posterURL {
                CachedAsyncImage(url: posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    FFColors.backgroundElevated
                }
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .lineLimit(1)

                // Date
                Text(entry.watchedDate, style: .date)
                    .font(FFTypography.caption)
                    .foregroundColor(FFColors.textTertiary)

                // Stars
                if let rating = entry.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(star <= rating ? FFColors.goldPrimary : FFColors.textTertiary)
                        }
                    }
                }

                // Review snippet
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
