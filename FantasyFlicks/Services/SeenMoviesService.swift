//
//  SeenMoviesService.swift
//  FantasyFlicks
//
//  Tracks movies the user has watched, with diary, watchlist, ratings,
//  reviews, and Letterboxd CSV import support
//

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Diary Entry

struct DiaryEntry: Codable, Identifiable, Hashable {
    let id: String
    let tmdbId: Int
    let watchedDate: Date
    var rating: Int?         // 1-5 stars
    var reviewText: String?
    var title: String        // cached for display without API call
    var posterPath: String?

    init(tmdbId: Int, watchedDate: Date = Date(), rating: Int? = nil,
         reviewText: String? = nil, title: String, posterPath: String? = nil) {
        self.id = UUID().uuidString
        self.tmdbId = tmdbId
        self.watchedDate = watchedDate
        self.rating = rating
        self.reviewText = reviewText
        self.title = title
        self.posterPath = posterPath
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "\(APIConfiguration.TMDB.imageBaseURL)/\(APIConfiguration.TMDB.PosterSize.medium.rawValue)\(posterPath)")
    }
}

// MARK: - Service

@MainActor
final class SeenMoviesService: ObservableObject {

    // MARK: - Singleton

    static let shared = SeenMoviesService()

    // MARK: - Published

    @Published var seenTmdbIds: Set<Int> = []
    @Published var ratings: [Int: Int] = [:]         // tmdbId -> 1-5 star rating
    @Published var diary: [DiaryEntry] = []
    @Published var watchlist: Set<Int> = []           // tmdbId set for want-to-watch
    @Published var isImporting = false
    @Published var lastImportCount: Int?

    // MARK: - Private Keys

    private let seenKey = "ff_seen_movie_tmdb_ids"
    private let ratingsKey = "ff_movie_ratings"
    private let diaryKey = "ff_movie_diary"
    private let watchlistKey = "ff_movie_watchlist"

    // MARK: - Init

    private init() {
        load()
    }

    // MARK: - Seen CRUD

    var count: Int { seenTmdbIds.count }

    func markSeen(tmdbId: Int) {
        seenTmdbIds.insert(tmdbId)
        save()
    }

    func markUnseen(tmdbId: Int) {
        seenTmdbIds.remove(tmdbId)
        ratings.removeValue(forKey: tmdbId)
        save()
    }

    func isSeen(tmdbId: Int) -> Bool {
        seenTmdbIds.contains(tmdbId)
    }

    func toggleSeen(tmdbId: Int) {
        if seenTmdbIds.contains(tmdbId) {
            seenTmdbIds.remove(tmdbId)
            ratings.removeValue(forKey: tmdbId)
        } else {
            seenTmdbIds.insert(tmdbId)
        }
        save()
    }

    func markMultipleSeen(tmdbIds: [Int]) {
        seenTmdbIds.formUnion(tmdbIds)
        save()
    }

    // MARK: - Ratings

    func setRating(tmdbId: Int, stars: Int) {
        let clamped = max(1, min(5, stars))
        ratings[tmdbId] = clamped
        seenTmdbIds.insert(tmdbId)
        save()
    }

    func removeRating(tmdbId: Int) {
        ratings.removeValue(forKey: tmdbId)
        save()
    }

    func rating(for tmdbId: Int) -> Int? {
        ratings[tmdbId]
    }

    // MARK: - Diary

    func addDiaryEntry(tmdbId: Int, title: String, posterPath: String? = nil,
                       watchedDate: Date = Date(), rating: Int? = nil, reviewText: String? = nil) {
        let entry = DiaryEntry(
            tmdbId: tmdbId, watchedDate: watchedDate,
            rating: rating, reviewText: reviewText,
            title: title, posterPath: posterPath
        )
        diary.insert(entry, at: 0) // newest first
        seenTmdbIds.insert(tmdbId)
        if let rating { setRating(tmdbId: tmdbId, stars: rating) }
        save()
    }

    func removeDiaryEntry(id: String) {
        diary.removeAll { $0.id == id }
        save()
    }

    func diaryEntries(for tmdbId: Int) -> [DiaryEntry] {
        diary.filter { $0.tmdbId == tmdbId }
    }

    // MARK: - Watchlist

    func addToWatchlist(tmdbId: Int) {
        watchlist.insert(tmdbId)
        save()
    }

    func removeFromWatchlist(tmdbId: Int) {
        watchlist.remove(tmdbId)
        save()
    }

    func isOnWatchlist(tmdbId: Int) -> Bool {
        watchlist.contains(tmdbId)
    }

    func toggleWatchlist(tmdbId: Int) {
        if watchlist.contains(tmdbId) {
            watchlist.remove(tmdbId)
        } else {
            watchlist.insert(tmdbId)
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        UserDefaults.standard.set(Array(seenTmdbIds), forKey: seenKey)
        UserDefaults.standard.set(Array(watchlist), forKey: watchlistKey)

        let ratingsDict = ratings.reduce(into: [String: Int]()) { $0["\($1.key)"] = $1.value }
        UserDefaults.standard.set(ratingsDict, forKey: ratingsKey)

        if let diaryData = try? JSONEncoder().encode(diary) {
            UserDefaults.standard.set(diaryData, forKey: diaryKey)
        }
    }

    private func load() {
        seenTmdbIds = Set(UserDefaults.standard.array(forKey: seenKey) as? [Int] ?? [])
        watchlist = Set(UserDefaults.standard.array(forKey: watchlistKey) as? [Int] ?? [])

        if let ratingsDict = UserDefaults.standard.dictionary(forKey: ratingsKey) as? [String: Int] {
            ratings = ratingsDict.reduce(into: [Int: Int]()) { result, pair in
                if let key = Int(pair.key) { result[key] = pair.value }
            }
        }

        if let diaryData = UserDefaults.standard.data(forKey: diaryKey),
           let decoded = try? JSONDecoder().decode([DiaryEntry].self, from: diaryData) {
            diary = decoded
        }
    }

    // MARK: - Letterboxd Import

    func importLetterboxd(from url: URL) async -> Int {
        isImporting = true
        defer { isImporting = false }

        guard url.startAccessingSecurityScopedResource() else { return 0 }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            guard let csvString = String(data: data, encoding: .utf8) else { return 0 }

            let entries = parseLetterboxdCSV(csvString)
            var matchedCount = 0

            // Process in batches of 5 to avoid TMDB rate limits
            let batchSize = 5
            for batchStart in stride(from: 0, to: entries.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, entries.count)
                let batch = Array(entries[batchStart..<batchEnd])

                await withTaskGroup(of: (LetterboxdEntry, Int?).self) { group in
                    for entry in batch {
                        group.addTask {
                            do {
                                let response = try await TMDBService.shared.searchMovies(query: entry.name, page: 1)
                                let match = response.results.first { movie in
                                    let titleMatch = movie.title.lowercased() == entry.name.lowercased()
                                    if let year = entry.year, let releaseDate = movie.releaseDate {
                                        let movieYear = Calendar.current.component(.year, from: releaseDate)
                                        return titleMatch && movieYear == year
                                    }
                                    return titleMatch
                                } ?? response.results.first
                                return (entry, match?.id)
                            } catch {
                                return (entry, nil)
                            }
                        }
                    }

                    for await (entry, tmdbId) in group {
                        guard let tmdbId else { continue }
                        matchedCount += 1
                        seenTmdbIds.insert(tmdbId)

                        // Import rating if present (Letterboxd 0.5-5.0 → 1-5 int)
                        let starRating: Int? = entry.rating.map { max(1, min(5, Int($0.rounded()))) }
                        if let stars = starRating {
                            ratings[tmdbId] = stars
                        }

                        // Determine the best date to use (Watched Date > Date > nil)
                        let dateStr = entry.watchedDate ?? entry.entryDate
                        let entryDate = dateStr.flatMap { parseLetterboxdDate($0) }

                        // Create a diary entry if we have either a date OR a review
                        // (Reviews without date become "today" entries — still valuable)
                        if entryDate != nil || entry.reviewText != nil {
                            let date = entryDate ?? Date()
                            let duplicate = diary.contains { existing in
                                existing.tmdbId == tmdbId &&
                                Calendar.current.isDate(existing.watchedDate, inSameDayAs: date) &&
                                existing.reviewText == entry.reviewText
                            }
                            if !duplicate {
                                let diaryEntry = DiaryEntry(
                                    tmdbId: tmdbId,
                                    watchedDate: date,
                                    rating: starRating,
                                    reviewText: entry.reviewText,
                                    title: entry.name
                                )
                                diary.append(diaryEntry)
                            }
                        }
                    }
                }
            }

            // Sort diary newest first
            diary.sort { $0.watchedDate > $1.watchedDate }
            save()
            lastImportCount = matchedCount
            return matchedCount
        } catch {
            return 0
        }
    }

    // MARK: - CSV Parsing

    private struct LetterboxdEntry {
        let name: String
        let year: Int?
        let rating: Double?
        let watchedDate: String?
        let reviewText: String?
        let entryDate: String?  // fallback from "Date" column on diary.csv
    }

    private func parseLetterboxdCSV(_ csv: String) -> [LetterboxdEntry] {
        var entries: [LetterboxdEntry] = []
        let lines = csv.components(separatedBy: .newlines)

        guard let headerLine = lines.first else { return [] }
        let headers = parseCSVRow(headerLine).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        let nameIndex = headers.firstIndex(of: "name") ?? headers.firstIndex(of: "title")
        let yearIndex = headers.firstIndex(of: "year")
        let ratingIndex = headers.firstIndex(of: "rating")
        let watchedDateIndex = headers.firstIndex(of: "watched date")
        let dateIndex = headers.firstIndex(of: "date")
        let reviewIndex = headers.firstIndex(of: "review")

        guard let nameIdx = nameIndex else { return [] }

        for line in lines.dropFirst() {
            let fields = parseCSVRow(line)
            guard nameIdx < fields.count else { continue }

            let name = fields[nameIdx].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            let year: Int? = yearIndex.flatMap { idx in
                idx < fields.count ? Int(fields[idx].trimmingCharacters(in: .whitespaces)) : nil
            }
            let rating: Double? = ratingIndex.flatMap { idx in
                idx < fields.count ? Double(fields[idx].trimmingCharacters(in: .whitespaces)) : nil
            }
            let watchedDate: String? = watchedDateIndex.flatMap { idx in
                idx < fields.count ? fields[idx].trimmingCharacters(in: .whitespaces) : nil
            }
            let entryDate: String? = dateIndex.flatMap { idx in
                idx < fields.count ? fields[idx].trimmingCharacters(in: .whitespaces) : nil
            }
            let reviewText: String? = reviewIndex.flatMap { idx -> String? in
                guard idx < fields.count else { return nil }
                let trimmed = fields[idx].trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? nil : trimmed
            }

            entries.append(LetterboxdEntry(
                name: name, year: year, rating: rating,
                watchedDate: watchedDate, reviewText: reviewText,
                entryDate: entryDate
            ))
        }

        return entries
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    private func parseLetterboxdDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}
