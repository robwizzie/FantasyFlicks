//
//  SeenMoviesService.swift
//  FantasyFlicks
//
//  Tracks movies the user has already seen, with Letterboxd CSV import support
//

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// Manages the user's "already seen" movie list using UserDefaults
@MainActor
final class SeenMoviesService: ObservableObject {

    // MARK: - Singleton

    static let shared = SeenMoviesService()

    // MARK: - Published

    @Published var seenTmdbIds: Set<Int> = []
    @Published var ratings: [Int: Int] = [:]  // tmdbId -> 1-5 star rating
    @Published var isImporting = false
    @Published var lastImportCount: Int?

    // MARK: - Private

    private let userDefaultsKey = "ff_seen_movie_tmdb_ids"
    private let ratingsKey = "ff_movie_ratings"

    // MARK: - Init

    private init() {
        load()
    }

    // MARK: - CRUD

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

    var count: Int { seenTmdbIds.count }

    // MARK: - Ratings

    func setRating(tmdbId: Int, stars: Int) {
        let clamped = max(1, min(5, stars))
        ratings[tmdbId] = clamped
        seenTmdbIds.insert(tmdbId)  // Rating implies seen
        save()
    }

    func removeRating(tmdbId: Int) {
        ratings.removeValue(forKey: tmdbId)
        save()
    }

    func rating(for tmdbId: Int) -> Int? {
        ratings[tmdbId]
    }

    // MARK: - Persistence

    private func save() {
        let array = Array(seenTmdbIds)
        UserDefaults.standard.set(array, forKey: userDefaultsKey)
        // Save ratings as [String: Int] since UserDefaults doesn't support Int keys
        let ratingsDict = ratings.reduce(into: [String: Int]()) { $0["\($1.key)"] = $1.value }
        UserDefaults.standard.set(ratingsDict, forKey: ratingsKey)
    }

    private func load() {
        let array = UserDefaults.standard.array(forKey: userDefaultsKey) as? [Int] ?? []
        seenTmdbIds = Set(array)
        // Load ratings
        if let ratingsDict = UserDefaults.standard.dictionary(forKey: ratingsKey) as? [String: Int] {
            ratings = ratingsDict.reduce(into: [Int: Int]()) { result, pair in
                if let key = Int(pair.key) { result[key] = pair.value }
            }
        }
    }

    // MARK: - Letterboxd Import

    /// Parse a Letterboxd CSV export and match movies against TMDB
    func importLetterboxd(from url: URL) async -> Int {
        isImporting = true
        defer { isImporting = false }

        guard url.startAccessingSecurityScopedResource() else { return 0 }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            guard let csvString = String(data: data, encoding: .utf8) else { return 0 }

            let entries = parseLetterboxdCSV(csvString)
            var matchedIds: [Int] = []

            // Search TMDB for each movie (batch with concurrency limit)
            await withTaskGroup(of: Int?.self) { group in
                for entry in entries {
                    group.addTask {
                        do {
                            let response = try await TMDBService.shared.searchMovies(query: entry.name, page: 1)
                            // Find best match by title + year
                            let match = response.results.first { movie in
                                let titleMatch = movie.title.lowercased() == entry.name.lowercased()
                                if let year = entry.year, let releaseDate = movie.releaseDate {
                                    let movieYear = Calendar.current.component(.year, from: releaseDate)
                                    return titleMatch && movieYear == year
                                }
                                return titleMatch
                            } ?? response.results.first // Fall back to first result
                            return match?.id
                        } catch {
                            return nil
                        }
                    }
                }

                for await tmdbId in group {
                    if let id = tmdbId {
                        matchedIds.append(id)
                    }
                }
            }

            markMultipleSeen(tmdbIds: matchedIds)
            lastImportCount = matchedIds.count
            return matchedIds.count
        } catch {
            return 0
        }
    }

    // MARK: - CSV Parsing

    private struct LetterboxdEntry {
        let name: String
        let year: Int?
    }

    private func parseLetterboxdCSV(_ csv: String) -> [LetterboxdEntry] {
        var entries: [LetterboxdEntry] = []
        let lines = csv.components(separatedBy: .newlines)

        guard let headerLine = lines.first else { return [] }
        let headers = parseCSVRow(headerLine).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        let nameIndex = headers.firstIndex(of: "name") ?? headers.firstIndex(of: "title")
        let yearIndex = headers.firstIndex(of: "year")

        guard let nameIdx = nameIndex else { return [] }

        for line in lines.dropFirst() {
            let fields = parseCSVRow(line)
            guard nameIdx < fields.count else { continue }

            let name = fields[nameIdx].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            var year: Int?
            if let yearIdx = yearIndex, yearIdx < fields.count {
                year = Int(fields[yearIdx].trimmingCharacters(in: .whitespaces))
            }

            entries.append(LetterboxdEntry(name: name, year: year))
        }

        return entries
    }

    /// Parse a single CSV row handling quoted fields
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
}

// MARK: - Letterboxd CSV Document Type

struct LetterboxdCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var data: Data

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
