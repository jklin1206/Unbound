import Foundation

final class NetworkService: NetworkServiceProtocol, @unchecked Sendable {
    static let shared = NetworkService()
    private let session: URLSession
    private let logger = LoggingService.shared

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConstants.Limits.networkTimeoutSeconds
        self.session = URLSession(configuration: config)
    }

    func request<T: Decodable>(endpoint: APIEndpoint) async throws -> T {
        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = endpoint.method
        urlRequest.httpBody = endpoint.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = endpoint.timeout

        var lastError: Error?

        for attempt in 1...AppConstants.Limits.maxRetryAttempts {
            do {
                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.networkServerError(statusCode: 0, message: "Invalid response")
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8)
                    throw AppError.networkServerError(statusCode: httpResponse.statusCode, message: message)
                }

                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    return decoded
                } catch {
                    throw AppError.networkDecodingFailed(underlying: error)
                }
            } catch let error as AppError {
                throw error
            } catch let error as URLError where error.code == .timedOut {
                throw AppError.networkTimeout
            } catch let error as URLError where error.code == .notConnectedToInternet {
                throw AppError.networkNoConnection
            } catch {
                lastError = error
                if attempt < AppConstants.Limits.maxRetryAttempts {
                    let delay = pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(for: .seconds(delay))
                    logger.log("Retry attempt \(attempt) for \(endpoint.url)", level: .warning)
                }
            }
        }

        throw AppError.unknown(underlying: lastError ?? NSError(domain: "NetworkService", code: -1))
    }
}
