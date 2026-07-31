//
//  TasteGraphService.swift
//  FantasyFlicks
//
//  User-to-user collaborative filtering across FantasyFlicks members.
//
//  Every member's ratings are already mirrored to their Firestore user doc as
//  `mediaRatings` so friends can read them. This turns that into a
//  recommendation signal: find the people whose ratings line up with yours,
//  then surface the films they rate highly that you haven't seen.
//
//  The model is a standard neighbourhood CF, with two deliberate choices:
//
//    1. Ratings are mean-centred per person before anything is compared. Two
//       people can agree completely about films and still disagree about where
//       "good" sits on a five-point scale; without centring, a generous rater
//       looks similar to everyone and drowns out the useful neighbours.
//
//    2. Similarity is damped by how much the two people have actually both
//       seen. Perfect agreement across three films is a coincidence, not a
//       taste match, and undamped cosine happily reports 1.0 for it.
//

import Foundation
import FirebaseFirestore

// MARK: - Neighbour

/// Another member whose ratings line up with ours, and how far we trust them.
struct TasteNeighbour: Identifiable, Sendable {
    let userId: String
    let displayName: String
    /// 0-1. Agreement on the films we've both rated, damped for a thin overlap
    /// and lifted when we agree specifically about the films we love.
    let similarity: Double
    /// How many films we've both rated.
    let overlapCount: Int
    /// Their personal average, used to centre their ratings.
    let meanRating: Double
    let ratings: [Int: Double]

    var id: String { userId }
}

// MARK: - Pick

/// A film our neighbours rate highly that we haven't seen.
struct NeighbourPick: Sendable {
    let tmdbId: Int
    /// What we predict this user would rate it, on the 0.5-5 scale.
    let predictedRating: Double
    /// 0-1. How much evidence sits behind the prediction — a single lukewarm
    /// neighbour and a dozen enthusiastic ones both produce a number, and the
    /// caller needs to be able to tell them apart.
    let confidence: Double
    /// Display names of neighbours who rated it 4+, closest taste first.
    let supporters: [String]
    let supporterCount: Int
    /// Mean rating among those supporters.
    let averageRating: Double

    /// Ranking value: a high prediction nobody can vouch for shouldn't outrank
    /// a slightly lower one that a dozen close matches agree on.
    ///
    /// Explicitly `nonisolated` — the target defaults declarations to
    /// `@MainActor`, and `picks(from:)` sorts on this from off the main actor.
    nonisolated var strength: Double { predictedRating * confidence }
}

// MARK: - Service

@MainActor
final class TasteGraphService {

    // MARK: - Singleton

    static let shared = TasteGraphService()

    // MARK: - Tuning

    /// Members pulled per refresh. Unordered on purpose — adding an `order(by:)`
    /// alongside the privacy equality filter would demand a composite Firestore
    /// index, and this query has to keep working without one.
    private let neighbourPoolSize = 300
    /// Below this many co-rated films, two people don't have comparable taste.
    private let minimumOverlap = 4
    /// Overlap at which the damping factor reaches full strength.
    private let overlapSaturation = 20
    /// Neighbours kept after ranking.
    private let maximumNeighbours = 40
    /// A neighbour weaker than this contributes nothing worth the arithmetic.
    private let minimumSimilarity = 0.05

    // MARK: - State

    private let db = Firestore.firestore()
    private let authService = AuthenticationService.shared

    /// Last computed neighbourhood, so the UI can explain where picks came from.
    private(set) var lastNeighbours: [TasteNeighbour] = []

    private init() {}

    // MARK: - Neighbourhood

    /// Find the members whose taste most resembles this user's.
    ///
    /// Returns an empty array rather than throwing — a community signal is an
    /// enhancement to the recommendations, never a precondition for them.
    func neighbours(
        of ourRatings: [Int: Double],
        ourMean: Double,
        lovedIds: Set<Int>
    ) async -> [TasteNeighbour] {
        guard ourRatings.count >= minimumOverlap else {
            lastNeighbours = []
            return []
        }

        let currentUserId = authService.currentUser?.id
        let blocked = Set(authService.currentUser?.blockedUserIds ?? [])

        let documents: [QueryDocumentSnapshot]
        do {
            documents = try await db.collection("users")
                .whereField("ratingsPrivate", isEqualTo: false)
                .limit(to: neighbourPoolSize)
                .getDocuments()
                .documents
        } catch {
            lastNeighbours = []
            return []
        }

        // Lift the Firestore payloads into plain values before the maths, so the
        // scoring loop can run off the main actor.
        let candidates: [(id: String, name: String, ratings: [Int: Double])] = documents.compactMap { document in
            let id = document.documentID
            guard id != currentUserId, !blocked.contains(id) else { return nil }

            let data = document.data()
            guard let raw = data["mediaRatings"] as? [String: Any] else { return nil }
            let ratings = Self.decodeRatings(raw)
            guard ratings.count >= minimumOverlap else { return nil }

            let name = (data["displayName"] as? String)
                ?? (data["username"] as? String)
                ?? "A member"
            return (id: id, name: name, ratings: ratings)
        }

        guard !candidates.isEmpty else {
            lastNeighbours = []
            return []
        }

        let minimumOverlap = self.minimumOverlap
        let overlapSaturation = self.overlapSaturation
        let maximumNeighbours = self.maximumNeighbours
        let minimumSimilarity = self.minimumSimilarity

        let ranked = await Task.detached(priority: .userInitiated) {
            candidates.compactMap { candidate -> TasteNeighbour? in
                Self.neighbour(
                    from: candidate,
                    ourRatings: ourRatings,
                    ourMean: ourMean,
                    lovedIds: lovedIds,
                    minimumOverlap: minimumOverlap,
                    overlapSaturation: overlapSaturation
                )
            }
            .filter { $0.similarity >= minimumSimilarity }
            .sorted { $0.similarity > $1.similarity }
            .prefix(maximumNeighbours)
            .map { $0 }
        }.value

        lastNeighbours = ranked
        return ranked
    }

    /// Score one candidate member against us.
    private nonisolated static func neighbour(
        from candidate: (id: String, name: String, ratings: [Int: Double]),
        ourRatings: [Int: Double],
        ourMean: Double,
        lovedIds: Set<Int>,
        minimumOverlap: Int,
        overlapSaturation: Int
    ) -> TasteNeighbour? {
        // Walk the smaller set — most members will have rated far fewer films
        // than a Letterboxd backfill produces, or far more.
        let theirRatings = candidate.ratings
        let shared: [Int] = ourRatings.count <= theirRatings.count
            ? ourRatings.keys.filter { theirRatings[$0] != nil }
            : theirRatings.keys.filter { ourRatings[$0] != nil }

        guard shared.count >= minimumOverlap else { return nil }

        let theirMean = theirRatings.values.reduce(0, +) / Double(theirRatings.count)

        var dot = 0.0
        var ourNorm = 0.0
        var theirNorm = 0.0
        var lovedShared = 0
        var lovedAgreed = 0

        for tmdbId in shared {
            guard let ours = ourRatings[tmdbId], let theirs = theirRatings[tmdbId] else { continue }
            let a = ours - ourMean
            let b = theirs - theirMean
            dot += a * b
            ourNorm += a * a
            theirNorm += b * b

            if lovedIds.contains(tmdbId) {
                lovedShared += 1
                if theirs >= 4.0 { lovedAgreed += 1 }
            }
        }

        // A flat rater (every film the same score) carries no directional
        // information — the cosine is undefined, not zero.
        guard ourNorm > 0, theirNorm > 0 else { return nil }

        let cosine = dot / (ourNorm.squareRoot() * theirNorm.squareRoot())
        guard cosine > 0 else { return nil }

        // Thin overlaps produce confident-looking nonsense; scale them down.
        let significance = Double(min(shared.count, overlapSaturation)) / Double(overlapSaturation)

        // The films this user rated 4+ are the ones the recommendations are
        // built from, so agreeing about *those* specifically matters more than
        // general correlation. No shared loved films leaves the base factor.
        let lovedAgreement = lovedShared > 0 ? Double(lovedAgreed) / Double(lovedShared) : 0.5
        let lovedFactor = 0.6 + 0.4 * lovedAgreement

        return TasteNeighbour(
            userId: candidate.id,
            displayName: candidate.name,
            similarity: cosine * significance * lovedFactor,
            overlapCount: shared.count,
            meanRating: theirMean,
            ratings: theirRatings
        )
    }

    // MARK: - Picks

    /// Predict how this user would rate the films their neighbours have seen
    /// and they haven't.
    ///
    /// Every neighbour rating of a candidate counts, not just the enthusiastic
    /// ones — a film half the neighbourhood disliked should be dragged down by
    /// that, which is exactly what a divisive film deserves. The 4+ ratings are
    /// tracked separately so the UI can say who's vouching for it.
    nonisolated static func picks(
        from neighbours: [TasteNeighbour],
        ourMean: Double,
        excluding excluded: Set<Int>,
        minimumSupporters: Int,
        limit: Int
    ) -> [NeighbourPick] {
        guard !neighbours.isEmpty else { return [] }

        struct Accumulator {
            var numerator = 0.0
            var denominator = 0.0
            var supporters: [(name: String, similarity: Double)] = []
            var supporterRatingTotal = 0.0
        }

        var pool: [Int: Accumulator] = [:]

        for neighbour in neighbours {
            for (tmdbId, rating) in neighbour.ratings where !excluded.contains(tmdbId) {
                var entry = pool[tmdbId] ?? Accumulator()
                entry.numerator += neighbour.similarity * (rating - neighbour.meanRating)
                entry.denominator += neighbour.similarity
                if rating >= 4.0 {
                    entry.supporters.append((name: neighbour.displayName, similarity: neighbour.similarity))
                    entry.supporterRatingTotal += rating
                }
                pool[tmdbId] = entry
            }
        }

        return pool.compactMap { tmdbId, entry -> NeighbourPick? in
            let supporterCount = entry.supporters.count
            guard supporterCount >= minimumSupporters, entry.denominator > 0 else { return nil }

            let predicted = min(5.0, max(0.5, ourMean + entry.numerator / entry.denominator))

            // Shrink toward "no opinion" when the evidence is thin. Two close
            // neighbours should read as more certain than one distant one, and
            // the raw weighted average can't express that on its own.
            let confidence = entry.denominator / (entry.denominator + 1.5)

            let names = entry.supporters
                .sorted { $0.similarity > $1.similarity }
                .prefix(3)
                .map { $0.name }

            return NeighbourPick(
                tmdbId: tmdbId,
                predictedRating: predicted,
                confidence: confidence,
                supporters: names,
                supporterCount: supporterCount,
                averageRating: entry.supporterRatingTotal / Double(supporterCount)
            )
        }
        .sorted { $0.strength > $1.strength }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Helpers

    /// Firestore hands numbers back as `Double`, `Int` or `NSNumber` depending
    /// on how they were written, and the keys are stringified tmdbIds.
    private nonisolated static func decodeRatings(_ raw: [String: Any]) -> [Int: Double] {
        raw.reduce(into: [Int: Double]()) { result, pair in
            guard let key = Int(pair.key) else { return }
            if let value = pair.value as? Double {
                result[key] = value
            } else if let value = pair.value as? Int {
                result[key] = Double(value)
            } else if let value = pair.value as? NSNumber {
                result[key] = value.doubleValue
            }
        }
    }
}
