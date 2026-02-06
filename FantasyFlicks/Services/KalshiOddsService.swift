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
    private let seriesMapping: [(seriesTicker: String, categoryId: String)] = [
        ("KXOSCARPIC", "best_picture"),
        ("KXOSCARDIR", "best_director"),
        ("KXOSCARACTO", "best_actor"),
        ("KXOSCARACTR", "best_actress"),
        ("KXOSCARSUPACTO", "best_supporting_actor"),
        ("KXOSCARSUPACTR", "best_supporting_actress"),
    ]

    /// Fetch Oscar odds from Kalshi for all available categories.
    /// Returns dictionary keyed by "nomineeName_categoryId" -> probability (0.0 to 1.0)
    /// and the count of successfully fetched categories.
    func fetchOscarOdds(nominees: [OscarNominee]) async -> (odds: [String: Double], categoriesFetched: Int) {
        var allOdds: [String: Double] = [:]
        var categoriesFetched = 0

        for mapping in seriesMapping {
            do {
                let markets = try await fetchMarkets(seriesTicker: mapping.seriesTicker)
                guard !markets.isEmpty else { continue }

                let categoryNominees = nominees.filter { $0.categoryId == mapping.categoryId }

                for market in markets {
                    if let nominee = matchNominee(market: market, nominees: categoryNominees) {
                        let probability = effectiveProbability(from: market)
                        if probability > 0 {
                            allOdds["\(nominee.name)_\(mapping.categoryId)"] = probability
                        }
                    }
                }

                if !markets.isEmpty {
                    categoriesFetched += 1
                }
            } catch {
                // Silently skip this category - will use fallback estimates
            }
        }

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
