//
//  NetworkManager.swift
//  FantasyFlicks
//
//  Generic network layer for making API requests
//

import Foundation

/// Errors that can occur during network operations
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case noData
    case unauthorized
    case rateLimited
    case serverError
    case networkUnavailable
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP Error \(code): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .unauthorized:
            return "Unauthorized - check your API token"
        case .rateLimited:
            return "Rate limited - please wait before trying again"
        case .serverError:
            return "Server error - please try again later"
        case .networkUnavailable:
            return "Network unavailable - check your connection"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

/// Network manager for making HTTP requests
@MainActor
final class NetworkManager {

    // MARK: - Singleton

    static let shared = NetworkManager()

    // MARK: - Properties

    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Initialization

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true

        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try multiple date formats
            let formatters: [DateFormatter] = [
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd"
                    return f
                }(),
                {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    return f
                }()
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
    }

    // MARK: - Public Methods

    /// Perform a GET request and decode the response
    func get<T: Decodable>(
        url: URL,
        headers: [String: String]? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add default headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add TMDB authorization header
        request.setValue(
            "Bearer \(APIConfiguration.TMDB.accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await performRequest(request)
    }

    /// Perform a POST request with a body and decode the response
    func post<T: Decodable, B: Encodable>(
        url: URL,
        body: B,
        headers: [String: String]? = nil
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Bearer \(APIConfiguration.TMDB.accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await performRequest(request)
    }

    // MARK: - Private Methods

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                break // Success
            case 401:
                throw NetworkError.unauthorized
            case 429:
                throw NetworkError.rateLimited
            case 500...599:
                throw NetworkError.serverError
            default:
                let message = String(data: data, encoding: .utf8)
                throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
            }

            // Decode the response
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                #if DEBUG
                print("Decoding error: \(error)")
                if let json = String(data: data, encoding: .utf8) {
                    print("Response JSON: \(json.prefix(1000))")
                }
                #endif
                throw NetworkError.decodingError(error)
            }

        } catch let error as NetworkError {
            throw error
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw NetworkError.networkUnavailable
            }
            throw NetworkError.unknown(error)
        } catch {
            throw NetworkError.unknown(error)
        }
    }
}

// MARK: - Image Loading

extension NetworkManager {
    /// Download image data from a URL
    func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        return data
    }
}
