import Foundation

struct ProgramTrainingContextOverride: Codable, Equatable, Identifiable {
    var id: String
    var userId: String
    var programId: String
    var selection: ProgramTrainingContextSelection
    var startsOn: Date?
    var endsBefore: Date?
    var createdAt: Date
    var updatedAt: Date

    var isDailyModifier: Bool {
        selection.scope == .todayOnly || selection.scope == .thisWeek
    }

    var isPendingNextBlock: Bool {
        selection.scope == .nextBlock
    }

    func applies(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isDailyModifier,
              let startsOn,
              let endsBefore
        else {
            return false
        }
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: startsOn) && day < calendar.startOfDay(for: endsBefore)
    }
}

/// Local user intent for temporary programming changes.
///
/// The generated block remains the base plan. Today/week records are consumed
/// by the daily resolver as modifiers; next-block records are consumed by
/// rollover generation and then cleared.
final class ProgramTrainingContextStore {
    static let shared = ProgramTrainingContextStore()

    private struct Cache: Codable, Equatable {
        var records: [ProgramTrainingContextOverride] = []
    }

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("program-training-contexts.json")
    }

    @discardableResult
    func saveDailyContext(
        selection: ProgramTrainingContextSelection,
        userId: String,
        programId: String,
        anchorDate: Date,
        calendar: Calendar = .current
    ) -> ProgramTrainingContextOverride {
        let window = dateWindow(for: selection.scope, anchorDate: anchorDate, calendar: calendar)
        let now = Date()
        let record = ProgramTrainingContextOverride(
            id: UUID().uuidString,
            userId: userId,
            programId: programId,
            selection: selection,
            startsOn: window.start,
            endsBefore: window.end,
            createdAt: now,
            updatedAt: now
        )

        var cache = readCache()
        cache.records.removeAll { existing in
            existing.userId == userId
                && existing.programId == programId
                && existing.selection.scope == selection.scope
                && existing.isDailyModifier
                && existing.applies(on: anchorDate, calendar: calendar)
        }
        cache.records.append(record)
        pruneExpiredDailyRecords(in: &cache, now: anchorDate, calendar: calendar)
        writeCache(cache)
        return record
    }

    @discardableResult
    func savePendingNextBlockContext(
        selection: ProgramTrainingContextSelection,
        userId: String,
        programId: String
    ) -> ProgramTrainingContextOverride {
        let now = Date()
        let normalizedSelection = ProgramTrainingContextSelection(
            scope: .nextBlock,
            mode: selection.mode,
            equipment: selection.equipment,
            experience: selection.experience
        )
        let record = ProgramTrainingContextOverride(
            id: UUID().uuidString,
            userId: userId,
            programId: programId,
            selection: normalizedSelection,
            startsOn: nil,
            endsBefore: nil,
            createdAt: now,
            updatedAt: now
        )

        var cache = readCache()
        cache.records.removeAll {
            $0.userId == userId
                && $0.programId == programId
                && $0.isPendingNextBlock
        }
        cache.records.append(record)
        writeCache(cache)
        return record
    }

    func activeDailyContext(
        userId: String,
        programId: String,
        date: Date,
        calendar: Calendar = .current
    ) -> ProgramTrainingContextOverride? {
        readCache().records
            .filter {
                $0.userId == userId
                    && $0.programId == programId
                    && $0.applies(on: date, calendar: calendar)
            }
            .sorted { lhs, rhs in
                let lhsRank = dailyScopeRank(lhs.selection.scope)
                let rhsRank = dailyScopeRank(rhs.selection.scope)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.createdAt > rhs.createdAt
            }
            .first
    }

    func pendingNextBlockContext(
        userId: String,
        programId: String
    ) -> ProgramTrainingContextOverride? {
        readCache().records
            .filter {
                $0.userId == userId
                    && $0.programId == programId
                    && $0.isPendingNextBlock
            }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    func consumePendingNextBlockContext(userId: String, programId: String) {
        clearPendingNextBlockContext(userId: userId, programId: programId)
    }

    @discardableResult
    func clearActiveDailyContext(
        userId: String,
        programId: String,
        date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let active = activeDailyContext(
            userId: userId,
            programId: programId,
            date: date,
            calendar: calendar
        ) else {
            return false
        }
        return clearDailyContext(id: active.id, userId: userId, programId: programId)
    }

    @discardableResult
    func clearDailyContext(id: String, userId: String, programId: String) -> Bool {
        var cache = readCache()
        let before = cache.records.count
        cache.records.removeAll {
            $0.id == id
                && $0.userId == userId
                && $0.programId == programId
                && $0.isDailyModifier
        }
        writeCache(cache)
        return cache.records.count != before
    }

    @discardableResult
    func clearPendingNextBlockContext(userId: String, programId: String) -> Bool {
        var cache = readCache()
        let before = cache.records.count
        cache.records.removeAll {
            $0.userId == userId
                && $0.programId == programId
                && $0.isPendingNextBlock
        }
        writeCache(cache)
        return cache.records.count != before
    }

    func clear(userId: String, programId: String) {
        var cache = readCache()
        cache.records.removeAll { $0.userId == userId && $0.programId == programId }
        writeCache(cache)
    }

    private func dateWindow(
        for scope: ProgramTrainingContextScope,
        anchorDate: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let startOfDay = calendar.startOfDay(for: anchorDate)
        switch scope {
        case .thisWeek:
            if let interval = calendar.dateInterval(of: .weekOfYear, for: anchorDate) {
                return (calendar.startOfDay(for: interval.start), interval.end)
            }
            let end = calendar.date(byAdding: .day, value: 7, to: startOfDay) ?? anchorDate
            return (startOfDay, end)
        case .todayOnly, .nextBlock, .ongoing, .freeformManual:
            let end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? anchorDate
            return (startOfDay, end)
        }
    }

    private func dailyScopeRank(_ scope: ProgramTrainingContextScope) -> Int {
        switch scope {
        case .todayOnly:
            return 0
        case .thisWeek:
            return 1
        case .nextBlock, .ongoing, .freeformManual:
            return 2
        }
    }

    private func pruneExpiredDailyRecords(
        in cache: inout Cache,
        now: Date,
        calendar: Calendar
    ) {
        let day = calendar.startOfDay(for: now)
        cache.records.removeAll { record in
            guard record.isDailyModifier, let endsBefore = record.endsBefore else { return false }
            return calendar.startOfDay(for: endsBefore) <= day
        }
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
