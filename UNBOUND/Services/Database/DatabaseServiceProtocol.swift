import Foundation

protocol DatabaseServiceProtocol: Sendable {
    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws
    func read<T: Codable>(collection: String, documentId: String) async throws -> T
    func update(_ fields: [String: Any], collection: String, documentId: String) async throws
    func delete(collection: String, documentId: String) async throws
    func query<T: Codable>(collection: String, field: String, isEqualTo value: Any, orderBy: String?, descending: Bool, limit: Int?) async throws -> [T]
}
