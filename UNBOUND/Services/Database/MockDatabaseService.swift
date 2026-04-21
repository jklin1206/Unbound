import Foundation

final class MockDatabaseService: DatabaseServiceProtocol, @unchecked Sendable {
    var store: [String: [String: Any]] = [:]

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
        let data = try JSONEncoder().encode(object)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        store["\(collection)/\(documentId)"] = dict
    }

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        guard let dict = store["\(collection)/\(documentId)"] else {
            throw AppError.databaseReadFailed(underlying: NSError(domain: "Mock", code: 404))
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
        let key = "\(collection)/\(documentId)"
        var existing = store[key] ?? [:]
        for (k, v) in fields { existing[k] = v }
        store[key] = existing
    }

    func delete(collection: String, documentId: String) async throws {
        store.removeValue(forKey: "\(collection)/\(documentId)")
    }

    func query<T: Codable>(collection: String, field: String, isEqualTo value: Any, orderBy: String?, descending: Bool, limit: Int?) async throws -> [T] {
        return []
    }
}
