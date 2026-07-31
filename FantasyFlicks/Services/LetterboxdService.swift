//
//  LetterboxdService.swift
//  FantasyFlicks
//
//  Connects a Letterboxd account and keeps the user's diary, ratings and
//  reviews in sync automatically.
//
//  Letterboxd has no public write/read API (their API is still invite-only),
//  but every member with a public profile publishes an RSS feed at
//  `https://letterboxd.com/{username}/rss/`. That feed carries everything we
//  need for a live connection:
//
//      <letterboxd:filmTitle>     the film
//      <letterboxd:filmYear>      release year
//      <letterboxd:memberRating>  0.5 - 5.0, half-star resolution
//      <letterboxd:watchedDate>   yyyy-MM-dd
//      <letterboxd:rewatch>       Yes / No
//      <tmdb:movieId>             the TMDB id — no fuzzy title matching needed
//      <description>              HTML review body
//
//  The feed only covers the ~50 most recent entries, so it's the *live* half
//  of the integration: CSV import backfills the full history once, and this
//  service picks up everything logged from then on.
//

import Foundation
import Combine

// MARK: - Parsed Feed Entry

/// One diary entry lifted from a Letterboxd RSS feed.
struct LetterboxdFeedEntry: Sendable, Hashable {
    /// Raw Letterboxd identifier for the entry (e.g. `letterboxd-review-123456`).
    let guid: String
    /// TMDB movie id straight from the feed. Nil for entries Letterboxd hasn't
    /// mapped (very rare) — we fall back to a title search in that case.
    let tmdbId: Int?
    let filmTitle: String
    let filmYear: Int?
    /// 0.5 - 5.0 in half-star steps. Nil when the entry was logged without a rating.
    let rating: Double?
    let watchedDate: Date?
    let publishedDate: Date?
    let reviewText: String?
    let isRewatch: Bool

    /// Best available date for the entry.
    var effectiveDate: Date {
        watchedDate ?? publishedDate ?? Date()
    }

    /// Identity we actually store and dedupe on.
    ///
    /// Letterboxd emits `letterboxd-watch-<id>` for a plain diary entry and
    /// `letterboxd-review-<id>` for the same entry once a review is attached —
    /// the numeric part is the viewing, and it doesn't change. Keying on that
    /// means adding a review to a film you already logged *updates* the diary
    /// entry here rather than creating a second one for the same night.
    var stableId: String {
        for prefix in ["letterboxd-watch-", "letterboxd-review-"] where guid.hasPrefix(prefix) {
            return "letterboxd-entry-\(guid.dropFirst(prefix.count))"
        }
        return guid
    }

    /// Fingerprint of the mutable content. When a user edits a review or
    /// changes a rating on Letterboxd the guid stays the same but this changes,
    /// which is how we know to re-apply an entry we've already seen.
    var contentHash: String {
        let ratingPart = rating.map { String(format: "%.1f", $0) } ?? "-"
        // The watched date is parsed from a plain yyyy-MM-dd string, so the
        // raw interval is already a stable per-day value.
        let datePart = watchedDate.map { String(Int($0.timeIntervalSince1970)) } ?? "-"
        return "\(ratingPart)|\(datePart)|\(isRewatch)|\(reviewText ?? "")".stableFingerprint
    }
}

// MARK: - Errors

enum LetterboxdError: LocalizedError {
    case invalidUsername
    case profileNotFound(String)
    case feedUnavailable
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "That doesn't look like a Letterboxd username. Use just the name from letterboxd.com/yourname."
        case .profileNotFound(let name):
            return "Couldn't find a public Letterboxd profile for \"\(name)\". Check the spelling, and make sure your profile isn't set to private."
        case .feedUnavailable:
            return "Couldn't reach Letterboxd right now. Try again in a moment."
        case .notConnected:
            return "No Letterboxd account is connected."
        }
    }
}

// MARK: - Service

@MainActor
final class LetterboxdService: ObservableObject {

    // MARK: - Singleton

    static let shared = LetterboxdService()

    // MARK: - Published State

    /// Connected Letterboxd username, or nil when no account is linked.
    @Published private(set) var username: String?

    /// When true, we sync on app launch / foreground (throttled).
    @Published var autoSyncEnabled: Bool = true {
        didSet { UserDefaults.standard.set(autoSyncEnabled, forKey: Keys.autoSync) }
    }

    @Published private(set) var lastSyncedAt: Date?
    /// Number of entries added or updated by the most recent sync.
    @Published private(set) var lastSyncChangeCount: Int?
    @Published private(set) var isSyncing = false
    @Published var syncError: String?

    var isConnected: Bool { username != nil }

    /// Public profile URL for the connected account.
    var profileURL: URL? {
        guard let username else { return nil }
        return URL(string: "https://letterboxd.com/\(username)/")
    }

    // MARK: - Config

    /// Don't hit Letterboxd more than once per this interval on automatic syncs.
    private let autoSyncMinimumInterval: TimeInterval = 15 * 60

    /// Cap on remembered entry fingerprints. The feed only holds ~50 entries,
    /// so this is many refreshes' worth of history.
    private let maxRememberedEntries = 400

    private enum Keys {
        static let username = "ff_letterboxd_username"
        static let autoSync = "ff_letterboxd_auto_sync"
        static let lastSynced = "ff_letterboxd_last_synced"
        static let seenEntries = "ff_letterboxd_seen_entries"
        static let seenOrder = "ff_letterboxd_seen_order"
    }

    // MARK: - Private State

    /// guid -> content fingerprint of the version we last applied.
    private var appliedEntries: [String: String] = [:]
    /// guids in the order we first applied them, so we can evict oldest first.
    private var appliedOrder: [String] = []

    /// Dedicated session — deliberately NOT `NetworkManager`, which attaches a
    /// TMDB bearer token to every request. Letterboxd should never see it.
    private let session: URLSession

    private var activeSync: Task<Int, Never>?

    // MARK: - Init

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)

        let defaults = UserDefaults.standard
        username = defaults.string(forKey: Keys.username)
        autoSyncEnabled = defaults.object(forKey: Keys.autoSync) as? Bool ?? true
        lastSyncedAt = defaults.object(forKey: Keys.lastSynced) as? Date
        appliedEntries = defaults.dictionary(forKey: Keys.seenEntries) as? [String: String] ?? [:]
        appliedOrder = defaults.array(forKey: Keys.seenOrder) as? [String] ?? []
    }

    // MARK: - Connect / Disconnect

    /// Link a Letterboxd account. Validates that the profile exists and is public
    /// by pulling its feed, then runs a first sync.
    /// - Returns: number of entries imported by the initial sync.
    @discardableResult
    func connect(username rawUsername: String) async throws -> Int {
        let cleaned = Self.normalizeUsername(rawUsername)
        guard Self.isPlausibleUsername(cleaned) else { throw LetterboxdError.invalidUsername }

        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        // Validate before persisting anything, so a typo doesn't leave the UI
        // showing a broken connection.
        let entries: [LetterboxdFeedEntry]
        do {
            entries = try await fetchFeed(for: cleaned)
        } catch let error as LetterboxdError {
            throw error
        } catch {
            throw LetterboxdError.feedUnavailable
        }

        username = cleaned
        UserDefaults.standard.set(cleaned, forKey: Keys.username)
        // Fresh connection — forget any fingerprints from a previously linked account.
        appliedEntries = [:]
        appliedOrder = []

        let changed = await apply(entries: entries)
        recordSyncCompletion(changeCount: changed)
        return changed
    }

    /// Unlink the account. Imported movies, ratings and reviews stay put —
    /// disconnecting stops future syncs, it doesn't undo past ones.
    func disconnect() {
        activeSync?.cancel()
        activeSync = nil
        username = nil
        lastSyncedAt = nil
        lastSyncChangeCount = nil
        syncError = nil
        appliedEntries = [:]
        appliedOrder = []

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.username)
        defaults.removeObject(forKey: Keys.lastSynced)
        defaults.removeObject(forKey: Keys.seenEntries)
        defaults.removeObject(forKey: Keys.seenOrder)
    }

    // MARK: - Sync

    /// Pull the feed and apply anything new or edited.
    /// - Returns: number of entries added or updated.
    @discardableResult
    func syncNow() async -> Int {
        guard let username else {
            syncError = LetterboxdError.notConnected.localizedDescription
            return 0
        }

        // Coalesce concurrent callers (foreground handler + pull-to-refresh)
        // onto a single network round-trip.
        if let activeSync { return await activeSync.value }

        // The task body inherits the MainActor context from this method, so the
        // published properties below are all touched on the main actor.
        let task = Task<Int, Never> { [weak self] in
            guard let self else { return 0 }
            self.isSyncing = true
            self.syncError = nil
            defer { self.isSyncing = false }

            do {
                let entries = try await self.fetchFeed(for: username)
                let changed = await self.apply(entries: entries)
                self.recordSyncCompletion(changeCount: changed)
                return changed
            } catch {
                self.syncError = (error as? LetterboxdError)?.localizedDescription
                    ?? LetterboxdError.feedUnavailable.localizedDescription
                return 0
            }
        }

        activeSync = task
        let result = await task.value
        activeSync = nil
        return result
    }

    /// Auto-sync entry point — no-ops unless connected, enabled, and enough
    /// time has passed since the last successful pull.
    @discardableResult
    func syncIfDue() async -> Int {
        guard isConnected, autoSyncEnabled, !isSyncing else { return 0 }
        if let lastSyncedAt, Date().timeIntervalSince(lastSyncedAt) < autoSyncMinimumInterval {
            return 0
        }
        return await syncNow()
    }

    private func recordSyncCompletion(changeCount: Int) {
        lastSyncedAt = Date()
        lastSyncChangeCount = changeCount
        UserDefaults.standard.set(lastSyncedAt, forKey: Keys.lastSynced)
        persistAppliedEntries()
    }

    // MARK: - Feed Fetching

    private func fetchFeed(for username: String) async throws -> [LetterboxdFeedEntry] {
        guard let url = URL(string: "https://letterboxd.com/\(username)/rss/") else {
            throw LetterboxdError.invalidUsername
        }

        var request = URLRequest(url: url)
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let fetched: (Data, URLResponse)
        do {
            fetched = try await session.data(for: request)
        } catch {
            throw LetterboxdError.feedUnavailable
        }
        let data = fetched.0

        if let http = fetched.1 as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299:
                break
            case 404, 403:
                // 404 = no such member. 403 = profile exists but isn't public.
                throw LetterboxdError.profileNotFound(username)
            default:
                throw LetterboxdError.feedUnavailable
            }
        }

        // An empty body means we got something that isn't a member feed.
        guard !data.isEmpty else { throw LetterboxdError.profileNotFound(username) }

        return await Task.detached(priority: .utility) {
            LetterboxdFeedParser().parse(data: data)
        }.value
    }

    // MARK: - Applying Entries

    /// Push new/edited entries into `SeenMoviesService`, oldest first so the
    /// most recent rating for a film is the one that sticks.
    private func apply(entries: [LetterboxdFeedEntry]) async -> Int {
        let pending = entries
            .filter { appliedEntries[$0.stableId] != $0.contentHash }
            .sorted { $0.effectiveDate < $1.effectiveDate }

        guard !pending.isEmpty else { return 0 }

        // Resolve every TMDB id first so the writes below can run as one
        // synchronous batch — a single persist instead of one per entry.
        var resolved: [(entry: LetterboxdFeedEntry, tmdbId: Int)] = []
        for entry in pending {
            if let tmdbId = await resolveTmdbId(for: entry) {
                resolved.append((entry: entry, tmdbId: tmdbId))
            }
        }
        guard !resolved.isEmpty else { return 0 }

        let seenService = SeenMoviesService.shared
        seenService.batchUpdate {
            for item in resolved {
                seenService.applyExternalDiaryEntry(
                    externalId: item.entry.stableId,
                    tmdbId: item.tmdbId,
                    title: item.entry.filmTitle,
                    watchedDate: item.entry.effectiveDate,
                    rating: item.entry.rating,
                    reviewText: item.entry.reviewText,
                    isRewatch: item.entry.isRewatch
                )
            }
        }

        for item in resolved {
            remember(guid: item.entry.stableId, hash: item.entry.contentHash)
        }

        await seenService.hydrateMissingMetadata(tmdbIds: resolved.map { $0.tmdbId })
        AchievementService.shared.forceUnlock("letterboxd_convert")

        return resolved.count
    }

    /// Prefer the TMDB id the feed hands us; fall back to a title+year search
    /// for the rare entry Letterboxd hasn't mapped.
    private func resolveTmdbId(for entry: LetterboxdFeedEntry) async -> Int? {
        if let id = entry.tmdbId { return id }

        guard let response = try? await TMDBService.shared.searchMovies(query: entry.filmTitle, page: 1),
              !response.results.isEmpty else { return nil }

        if let year = entry.filmYear {
            let exact = response.results.first { movie in
                guard let date = movie.releaseDate else { return false }
                let sameTitle = movie.title.lowercased() == entry.filmTitle.lowercased()
                    || (movie.originalTitle?.lowercased() ?? "") == entry.filmTitle.lowercased()
                return sameTitle && abs(Calendar.current.component(.year, from: date) - year) <= 1
            }
            if let exact { return exact.id }
        }

        return response.results.first {
            $0.title.lowercased() == entry.filmTitle.lowercased()
        }?.id
    }

    private func remember(guid: String, hash: String) {
        if appliedEntries[guid] == nil {
            appliedOrder.append(guid)
        }
        appliedEntries[guid] = hash

        // Evict oldest fingerprints once we're over the cap.
        while appliedOrder.count > maxRememberedEntries {
            let oldest = appliedOrder.removeFirst()
            appliedEntries.removeValue(forKey: oldest)
        }
    }

    private func persistAppliedEntries() {
        let defaults = UserDefaults.standard
        defaults.set(appliedEntries, forKey: Keys.seenEntries)
        defaults.set(appliedOrder, forKey: Keys.seenOrder)
    }

    // MARK: - Username Helpers

    /// Accepts a bare username, an `@name`, or a full profile URL and returns
    /// the bare username Letterboxd expects in a feed path.
    static func normalizeUsername(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        for prefix in ["https://", "http://"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }
        if value.hasPrefix("www.") { value.removeFirst(4) }
        if value.hasPrefix("letterboxd.com/") { value.removeFirst("letterboxd.com/".count) }
        if value.hasPrefix("@") { value.removeFirst() }

        // Strip any trailing path ("/films", "/rss/", …) and query string.
        if let slash = value.firstIndex(of: "/") { value = String(value[value.startIndex..<slash]) }
        if let question = value.firstIndex(of: "?") { value = String(value[value.startIndex..<question]) }

        return value
    }

    /// Letterboxd usernames are alphanumeric with underscores, 2-32 characters.
    static func isPlausibleUsername(_ value: String) -> Bool {
        guard (2...32).contains(value.count) else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

// MARK: - RSS Parser

/// Streaming parser for a Letterboxd member feed.
///
/// Namespace processing stays off, so element names arrive qualified
/// (`letterboxd:memberRating`, `tmdb:movieId`) and we can match them directly.
private final class LetterboxdFeedParser: NSObject, XMLParserDelegate {

    private var entries: [LetterboxdFeedEntry] = []

    // Element text accumulator. XMLParser hands characters over in arbitrary
    // chunks, so everything funnels through here and is banked on element end.
    private var buffer = ""
    private var inItem = false

    // Per-item fields
    private var guid: String?
    private var filmTitle: String?
    private var filmYear: Int?
    private var memberRating: Double?
    private var watchedDate: Date?
    private var publishedDate: Date?
    private var reviewHTML: String?
    private var isRewatch = false
    private var tmdbMovieId: Int?
    private var isListEntry = false

    private lazy var dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private lazy var rfc822Formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        // Letterboxd emits a non-padded day, e.g. "Wed, 6 Mar 2024 12:00:00 +1300"
        f.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return f
    }()

    func parse(data: Data) -> [LetterboxdFeedEntry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.parse()
        return entries
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        buffer = ""
        if elementName == "item" {
            inItem = true
            resetItem()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, let text = String(data: CDATABlock, encoding: .utf8) else { return }
        buffer += text
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard inItem else { return }

        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""

        switch elementName {
        case "guid":
            guid = value
        case "letterboxd:filmTitle":
            filmTitle = value
        case "letterboxd:filmYear":
            filmYear = Int(value)
        case "letterboxd:memberRating":
            memberRating = Double(value)
        case "letterboxd:watchedDate":
            watchedDate = dayFormatter.date(from: value)
        case "letterboxd:rewatch":
            isRewatch = value.lowercased() == "yes"
        case "letterboxd:listId", "letterboxd:listTitle":
            // Lists share the feed with diary entries — flag and skip them.
            isListEntry = true
        case "tmdb:movieId":
            tmdbMovieId = Int(value)
        case "description":
            reviewHTML = value
        case "pubDate":
            publishedDate = rfc822Formatter.date(from: value)
        case "item":
            finishItem()
            inItem = false
        default:
            break
        }
    }

    // MARK: Item assembly

    private func resetItem() {
        guid = nil
        filmTitle = nil
        filmYear = nil
        memberRating = nil
        watchedDate = nil
        publishedDate = nil
        reviewHTML = nil
        isRewatch = false
        tmdbMovieId = nil
        isListEntry = false
    }

    private func finishItem() {
        defer { resetItem() }

        // Only diary/review entries carry a film title. Lists and any other
        // feed noise get dropped.
        guard !isListEntry,
              let guid, !guid.isEmpty,
              let filmTitle, !filmTitle.isEmpty else { return }

        entries.append(LetterboxdFeedEntry(
            guid: guid,
            tmdbId: tmdbMovieId,
            filmTitle: filmTitle,
            filmYear: filmYear,
            rating: memberRating.map { max(0.5, min(5.0, ($0 * 2).rounded() / 2)) },
            watchedDate: watchedDate,
            publishedDate: publishedDate,
            reviewText: Self.extractReviewText(from: reviewHTML),
            isRewatch: isRewatch
        ))
    }

    /// The `<description>` body is HTML: a poster `<img>` wrapped in a `<p>`,
    /// optionally followed by the review paragraphs, and sometimes a trailing
    /// "Watched on …" line Letterboxd adds for entries without a review.
    /// Returns nil when nothing meaningful is left.
    static func extractReviewText(from html: String?) -> String? {
        guard let html, !html.isEmpty else { return nil }

        // Drop image tags entirely — they carry no review text.
        var text = html.replacingOccurrences(
            of: "<img[^>]*>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Turn block breaks into newlines before stripping the rest of the tags,
        // so paragraph structure in a long review survives.
        for (pattern, replacement) in [("<br\\s*/?>", "\n"), ("</p>", "\n\n")] {
            text = text.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.decodingHTMLEntities

        // Tidy the whitespace stripped markup leaves behind: the space that
        // used to sit between block tags, then runs of blank lines.
        text = text.replacingOccurrences(of: "\n[ \t]+", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Letterboxd appends this line to rating-only entries; it's not a review.
        if text.range(of: "^Watched on [^\\n]+\\.?$", options: [.regularExpression]) != nil {
            return nil
        }

        return text.isEmpty ? nil : text
    }
}

// MARK: - String Helpers

private extension String {
    /// Decode the handful of HTML entities that show up in Letterboxd reviews.
    var decodingHTMLEntities: String {
        var result = self

        // Numeric entities first (&#8217; &#x2019;), then named ones. `&amp;`
        // is intentionally last so "&amp;lt;" doesn't collapse into "<".
        for pattern in ["&#([0-9]+);", "&#[xX]([0-9a-fA-F]+);"] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let isHex = pattern.contains("x")
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let full = Range(match.range, in: result),
                      let digits = Range(match.range(at: 1), in: result),
                      let code = UInt32(result[digits], radix: isHex ? 16 : 10),
                      let scalar = Unicode.Scalar(code) else { continue }
                result.replaceSubrange(full, with: String(Character(scalar)))
            }
        }

        let named: [(String, String)] = [
            ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
            ("&apos;", "'"), ("&nbsp;", " "), ("&hellip;", "…"),
            ("&mdash;", "—"), ("&ndash;", "–"), ("&amp;", "&")
        ]
        for (entity, character) in named {
            result = result.replacingOccurrences(of: entity, with: character)
        }

        return result
    }

    /// Cheap, stable fingerprint (FNV-1a) for change detection. Not
    /// cryptographic — it only needs to differ when the text differs.
    var stableFingerprint: String {
        var hash: UInt64 = 14_695_981_039_346_656_037 // FNV-1a offset basis
        for byte in self.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 36)
    }
}
