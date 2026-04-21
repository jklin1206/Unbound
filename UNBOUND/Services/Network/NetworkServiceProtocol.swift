import Foundation

protocol NetworkServiceProtocol: Sendable {
    func request<T: Decodable>(endpoint: APIEndpoint) async throws -> T
}
