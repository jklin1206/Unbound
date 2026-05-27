import Foundation

/// Static collection→table/column mapping. The single source of truth for
/// which local collections sync and how they key by user.
enum SyncCollectionMap {
    private static let tables: [String: String] = [
        "workoutLogs": "workout_logs",
        "programs": "programs",
        "progressionState": "progression_state",
        "exercisePreferences": "exercise_preferences",
        "programBlocks": "program_blocks",
        "scanCheckpoints": "scan_checkpoints",
        "users": "users",
    ]
    static func table(for collection: String) -> String? { tables[collection] }
    static func userColumn(for collection: String) -> String {
        collection == "users" ? "id" : "user_id"
    }
    static var syncedCollections: [String] { Array(tables.keys) }
}

/// Network seam. One implementation (Supabase); mockable in tests.
protocol RemoteSync: Sendable {
    func upsert(collection: String, docId: String, json: Data) async throws
    func delete(collection: String, docId: String) async throws
    func pull(collection: String, userId: String) async throws -> [Data]
}

/// Adapter over SupabaseDatabase. Documents move as type-erased JSON.
final class SupabaseRemoteSync: RemoteSync, @unchecked Sendable {
    static let shared = SupabaseRemoteSync()
    private let supabase = SupabaseDatabase.shared
    private init() {}

    /// Supabase tables are snake_case. The outbox stores documents with the
    /// app's camelCase keys (from the local JSON store). Supabase-swift's
    /// key strategy only rewrites synthesized struct CodingKeys, not the
    /// dictionary keys we push via JSONElement — so convert here.
    static func normalizedPayload(collection: String, data: Data) -> Data {
        if collection == "programs",
           let programData = try? ProgramSupabasePayload.encodedJSON(fromProgramJSON: data) {
            return programData
        }
        return snakeCasedJSON(data)
    }

    static func snakeCasedJSON(_ data: Data) -> Data {
        func toSnake(_ s: String) -> String {
            var out = ""
            for ch in s {
                if ch.isUppercase { out += "_"; out += ch.lowercased() }
                else { out.append(ch) }
            }
            return out
        }
        func walk(_ value: Any) -> Any {
            if let dict = value as? [String: Any] {
                var result = [String: Any]()
                for (k, v) in dict { result[toSnake(k)] = walk(v) }
                return result
            }
            if let arr = value as? [Any] { return arr.map(walk) }
            return value
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let out = try? JSONSerialization.data(withJSONObject: walk(obj))
        else { return data }
        return out
    }

    static func camelCasedJSON(_ data: Data) -> Data {
        func toCamel(_ s: String) -> String {
            let parts = s.split(separator: "_", omittingEmptySubsequences: false)
            guard let first = parts.first else { return s }
            return parts.dropFirst().reduce(String(first)) { partial, part in
                guard let firstChar = part.first else { return partial }
                return partial + firstChar.uppercased() + String(part.dropFirst())
            }
        }
        func walk(_ value: Any) -> Any {
            if let dict = value as? [String: Any] {
                var result = [String: Any]()
                for (k, v) in dict { result[toCamel(k)] = walk(v) }
                return result
            }
            if let arr = value as? [Any] { return arr.map(walk) }
            return value
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let out = try? JSONSerialization.data(withJSONObject: walk(obj))
        else { return data }
        return out
    }

    func upsert(collection: String, docId: String, json: Data) async throws {
        guard let table = SyncCollectionMap.table(for: collection) else { return }
        let normalized = Self.normalizedPayload(collection: collection, data: json)
        let obj = try JSONDecoder().decode(JSONElement.self, from: normalized)
        _ = try await supabase.upsert(obj, into: table)
    }

    func delete(collection: String, docId: String) async throws {
        guard let table = SyncCollectionMap.table(for: collection) else { return }
        try await supabase.delete(from: table, keyedBy: "id", equals: docId)
    }

    func pull(collection: String, userId: String) async throws -> [Data] {
        guard let table = SyncCollectionMap.table(for: collection) else { return [] }
        let rows: [JSONElement] = try await supabase.query(
            from: table,
            whereColumn: SyncCollectionMap.userColumn(for: collection),
            equals: userId, orderBy: nil, ascending: false, limit: nil
        )
        return try rows.map { try Self.camelCasedJSON(JSONEncoder().encode($0)) }
    }
}

/// Type-erased JSON value so the generic sync path can move arbitrary
/// document shapes through Supabase-swift's Codable APIs.
indirect enum JSONElement: Codable, Sendable {
    case object([String: JSONElement])
    case array([JSONElement])
    case bool(Bool)
    case number(Double)
    case string(String)
    case null

    var value: Any {
        switch self {
        case .object(let value): return value
        case .array(let value): return value
        case .bool(let value): return value
        case .number(let value): return value
        case .string(let value): return value
        case .null: return NSNull()
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode([String: JSONElement].self) {
            self = .object(value)
        } else if let value = try? c.decode([JSONElement].self) {
            self = .array(value)
        } else if let value = try? c.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? c.decode(Double.self) {
            self = .number(value)
        } else if let value = try? c.decode(String.self) {
            self = .string(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let value): try c.encode(value)
        case .array(let value): try c.encode(value)
        case .bool(let value): try c.encode(value)
        case .number(let value): try c.encode(value)
        case .string(let value): try c.encode(value)
        case .null: try c.encodeNil()
        }
    }
}
