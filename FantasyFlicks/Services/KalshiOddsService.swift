//
//  KalshiOddsService.swift
//  FantasyFlicks
//
//  Fetches real-time Oscar prediction odds from the Kalshi prediction market API.
//  No authentication required for reading market data.
//

import Foundation

@MainActor
final class KalshiOddsService {

    static let shared = KalshiOddsService()
    private init() {}

    private let baseURL = "https://api.elections.kalshi.com/trade-api/v2"

    /// Maps Kalshi series tickers to our Oscar category IDs
    /// Note: Kalshi typically only has markets for major categories
    /// Additional categories are included for when they become available
    private let seriesMapping: [(seriesTicker: String, categoryId: String)] = [
        // Major Categories (typically available on Kalshi)
        ("KXOSCARPIC", "best_picture"),
        ("KXOSCARDIR", "best_director"),
        ("KXOSCARACTO", "best_actor"),
        ("KXOSCARACTR", "best_actress"),
        ("KXOSCARSUPACTO", "best_supporting_actor"),
        ("KXOSCARSUPACTR", "best_supporting_actress"),

        // Writing Categories
        ("KXOSCARORIGSCR", "best_original_screenplay"),
        ("KXOSCARADAPTSCR", "best_adapted_screenplay"),

        // Popular Categories
        ("KXOSCARANIM", "best_animated_feature"),
        ("KXOSCARINTL", "best_international_feature"),
        ("KXOSCARDOC", "best_documentary_feature"),

        // Technical Categories
        ("KXOSCARCINEMA", "best_cinematography"),
        ("KXOSCAREDIT", "best_film_editing"),
        ("KXOSCARSCORE", "best_original_score"),
        ("KXOSCARSONG", "best_original_song"),
        ("KXOSCARVFX", "best_visual_effects"),
        ("KXOSCARSOUND", "best_sound"),
        ("KXOSCARPROD", "best_production_design"),
        ("KXOSCARCOSTUME", "best_costume_design"),
        ("KXOSCARMAKEUP", "best_makeup_hairstyling"),
        ("KXOSCARCAST", "best_casting"),
    ]

    /// Fetch Oscar odds from Kalshi for all available categories.
    /// Returns dictionary keyed by "nomineeName_categoryId" -> probability (0.0 to 1.0)
    /// and the count of successfully fetched categories.
    func fetchOscarOdds(nominees: [OscarNominee]) async -> (odds: [String: Double], categoriesFetched: Int) {
        var allOdds: [String: Double] = [:]
        var categoriesFetched = 0

        print("[Kalshi] Fetching Oscar odds for \(seriesMapping.count) categories...")

        for mapping in seriesMapping {
            do {
                let markets = try await fetchMarkets(seriesTicker: mapping.seriesTicker)

                if markets.isEmpty {
                    print("[Kalshi] \(mapping.categoryId): No markets available (series may not exist yet)")
                    continue
                }

                print("[Kalshi] \(mapping.categoryId): \(markets.count) markets found")

                let categoryNominees = nominees.filter { $0.categoryId == mapping.categoryId }

                guard !categoryNominees.isEmpty else {
                    print("[Kalshi] \(mapping.categoryId): No nominees in our database, skipping")
                    continue
                }

                var matchCount = 0

                for market in markets {
                    if let nominee = matchNominee(market: market, nominees: categoryNominees) {
                        let probability = effectiveProbability(from: market)
                        if probability > 0 {
                            allOdds["\(nominee.name)_\(mapping.categoryId)"] = probability
                            matchCount += 1
                            print("[Kalshi]   ✓ \(nominee.name) = \(Int(probability * 100))%")
                        }
                    } else {
                        print("[Kalshi]   ⚠️ No match for market: \"\(market.title)\"")
                    }
                }

                if matchCount > 0 {
                    print("[Kalshi] \(mapping.categoryId): \(matchCount)/\(categoryNominees.count) nominees matched")
                    categoriesFetched += 1
                } else {
                    print("[Kalshi] \(mapping.categoryId): 0 nominees matched - check market naming")
                }
            } catch {
                // Only log as error if it's not a 404 (series not found)
                let errorMsg = error.localizedDescription
                if errorMsg.contains("404") || errorMsg.contains("not found") {
                    print("[Kalshi] \(mapping.categoryId): Series not available on Kalshi")
                } else {
                    print("[Kalshi] \(mapping.categoryId): ERROR - \(errorMsg)")
                }
            }
        }

        print("[Kalshi] Done. \(allOdds.count) total odds fetched across \(categoriesFetched) categories")
        return (allOdds, categoriesFetched)
    }

    // MARK: - Private

    private func fetchMarkets(seriesTicker: String) async throws -> [KalshiMarket] {
        guard let url = URL(string: "\(baseURL)/markets?series_ticker=\(seriesTicker)&status=open&limit=50") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decoder.decode(KalshiMarketsResponse.self, from: data)
        return result.markets
    }

    /// Calculate effective probability from market data.
    /// Uses last_price if available, otherwise midpoint of bid/ask.
    private func effectiveProbability(from market: KalshiMarket) -> Double {
        if market.lastPrice > 0 {
            return Double(market.lastPrice) / 100.0
        }
        // Fallback to midpoint of bid/ask
        let mid = (market.yesBid + market.yesAsk) / 2
        return mid > 0 ? Double(mid) / 100.0 : 0
    }

    /// Try to match a Kalshi market to one of our nominees by name.
    /// Kalshi titles are typically like "Best Picture: Anora" or "Adrien Brody".
    private func matchNominee(market: KalshiMarket, nominees: [OscarNominee]) -> OscarNominee? {
        let marketText = "\(market.title) \(market.subtitle ?? "")".lowercased()

        // Try matching each nominee's name and movie title against the market text
        for nominee in nominees {
            let name = nominee.name.lowercased()
            let movie = (nominee.movieTitle ?? "").lowercased()

            if marketText.contains(name) {
                return nominee
            }
            // For Best Picture, movies are the nominees - also check movie title
            if !movie.isEmpty && marketText.contains(movie) {
                return nominee
            }
        }

        // Try matching with simplified names (remove special characters)
        let simplifiedMarketText = marketText.folding(options: .diacriticInsensitive, locale: .current)
        for nominee in nominees {
            let simplifiedName = nominee.name.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            if simplifiedMarketText.contains(simplifiedName) {
                return nominee
            }
        }

        return nil
    }
}

// MARK: - Kalshi API Models

struct KalshiMarketsResponse: Codable {
    let markets: [KalshiMarket]
    let cursor: String?
}

struct KalshiMarket: Codable {
    let ticker: String
    let title: String
    let subtitle: String?
    let yesBid: Int
    let yesAsk: Int
    let lastPrice: Int
    let volume: Int?
    let volume24h: Int?
    let openInterest: Int?
    let status: String
}
