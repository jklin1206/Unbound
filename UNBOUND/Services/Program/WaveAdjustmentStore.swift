import Foundation

/// Local-only v1 undo state for Wave 2 adjustment rows.
///
/// The Wave engine is deterministic, so the durable thing we need to store is
/// the user's per-row "do not apply/show this again for this Arc" decision.
final class WaveAdjustmentStore {
    static let shared = WaveAdjustmentStore()

    private struct Record: Codable, Equatable {
        var userId: String
        var programId: String
        var revertedAdjustmentIDs: [String]
        var updatedAt: Date
    }

    private struct Cache: Codable, Equatable {
        var records: [Record] = []
    }

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("wave-adjustments.json")
    }

    func revertedAdjustmentIDs(userId: String, programId: String) -> Set<String> {
        guard let record = readCache().records.first(where: {
            $0.userId == userId && $0.programId == programId
        }) else {
            return []
        }
        return Set(record.revertedAdjustmentIDs)
    }

    func markReverted(_ adjustmentID: String, userId: String, programId: String) {
        guard !adjustmentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        var cache = readCache()
        if let index = cache.records.firstIndex(where: {
            $0.userId == userId && $0.programId == programId
        }) {
            var ids = Set(cache.records[index].revertedAdjustmentIDs)
            ids.insert(adjustmentID)
            cache.records[index].revertedAdjustmentIDs = ids.sorted()
            cache.records[index].updatedAt = Date()
        } else {
            cache.records.append(
                Record(
                    userId: userId,
                    programId: programId,
                    revertedAdjustmentIDs: [adjustmentID],
                    updatedAt: Date()
                )
            )
        }
        writeCache(cache)
    }

    func clear(userId: String, programId: String) {
        var cache = readCache()
        cache.records.removeAll { $0.userId == userId && $0.programId == programId }
        writeCache(cache)
    }

    private func readCache() -> Cache {
        guard let data = try? Data(contentsOf: fileURL),
              let cache = try? decoder.decode(Cache.self, from: data)
        else {
            return Cache()
        }
        return cache
    }

    private func writeCache(_ cache: Cache) {
        guard let data = try? encoder.encode(cache) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
