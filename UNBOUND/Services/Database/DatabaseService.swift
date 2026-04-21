import Foundation

// MARK: - DatabaseService (local-first)
//
// File-backed JSON document store replacing Firestore. Same interface —
// callers don't change. Layout on disk:
//
//   .../Documents/Database/<collection>/<documentId>.json
//
// Queries do in-memory filtering across all documents in a collection.
// That's fine for Day-1 scale (onboarding + a handful of scans per user);
// when we add real backends / leaderboards we swap this out.

final class DatabaseService: DatabaseServiceProtocol, @unchecked Sendable {
    static let shared = DatabaseService()
    private let logger = LoggingService.shared
    private let fm = FileManager.default

    private lazy var rootURL: URL = {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Database", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    // MARK: Protocol

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
        let url = try fileURL(collection: collection, documentId: documentId, createParent: true)
        do {
            let data = try encoder.encode(object)
            try data.write(to: url, options: [.atomic])
        } catch {
            logger.log("DB create failed: \(error)", level: .error, context: ["collection": collection, "docId": documentId])
            throw AppError.databaseWriteFailed(underlying: error)
        }
    }

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        let url = try fileURL(collection: collection, documentId: documentId, createParent: false)
        guard fm.fileExists(atPath: url.path) else {
            throw AppError.databaseReadFailed(
                underlying: NSError(domain: "DB", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document not found"])
            )
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch let error as AppError {
            throw error
        } catch {
            logger.log("DB read failed: \(error)", level: .error, context: ["collection": collection, "docId": documentId])
            throw AppError.databaseReadFailed(underlying: error)
        }
    }

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
        let url = try fileURL(collection: collection, documentId: documentId, createParent: true)
        var current: [String: Any] = [:]
        if fm.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            current = obj
        }
        for (k, v) in fields {
            current[k] = v
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: current, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: [.atomic])
        } catch {
            logger.log("DB update failed: \(error)", level: .error, context: ["collection": collection, "docId": documentId])
            throw AppError.databaseWriteFailed(underlying: error)
        }
    }

    func delete(collection: String, documentId: String) async throws {
        let url = try fileURL(collection: collection, documentId: documentId, createParent: false)
        guard fm.fileExists(atPath: url.path) else { return }
        do {
            try fm.removeItem(at: url)
        } catch {
            logger.log("DB delete failed: \(error)", level: .error, context: ["collection": collection, "docId": documentId])
            throw AppError.databaseWriteFailed(underlying: error)
        }
    }

    func query<T: Codable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        orderBy: String? = nil,
        descending: Bool = true,
        limit: Int? = nil
    ) async throws -> [T] {
        let collectionURL = rootURL.appendingPathComponent(collection, isDirectory: true)
        guard fm.fileExists(atPath: collectionURL.path) else { return [] }

        let files = (try? fm.contentsOfDirectory(at: collectionURL, includingPropertiesForKeys: nil)) ?? []
        let jsonFiles = files.filter { $0.pathExtension == "json" }

        // Load every doc, filter by the equality predicate, decode.
        var matches: [(date: Date, obj: T, raw: [String: Any])] = []
        for url in jsonFiles {
            guard let data = try? Data(contentsOf: url) else { continue }
            guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if !valuesEqual(raw[field], value) { continue }
            guard let obj = try? decoder.decode(T.self, from: data) else { continue }
            let date = (raw[orderBy ?? "createdAt"] as? String)
                .flatMap { ISO8601DateFormatter().date(from: $0) } ?? .distantPast
            matches.append((date, obj, raw))
        }

        if let orderBy, !orderBy.isEmpty {
            matches.sort { a, b in
                descending ? a.date > b.date : a.date < b.date
            }
        }

        let limited = limit.map { Array(matches.prefix($0)) } ?? matches
        return limited.map(\.obj)
    }

    // MARK: Helpers

    private func fileURL(collection: String, documentId: String, createParent: Bool) throws -> URL {
        let collectionURL = rootURL.appendingPathComponent(collection, isDirectory: true)
        if createParent {
            try fm.createDirectory(at: collectionURL, withIntermediateDirectories: true)
        }
        return collectionURL.appendingPathComponent("\(documentId).json")
    }

    private func valuesEqual(_ lhs: Any?, _ rhs: Any) -> Bool {
        guard let lhs else { return false }
        if let l = lhs as? String, let r = rhs as? String { return l == r }
        if let l = lhs as? Int, let r = rhs as? Int { return l == r }
        if let l = lhs as? Double, let r = rhs as? Double { return l == r }
        if let l = lhs as? Bool, let r = rhs as? Bool { return l == r }
        return false
    }
}
