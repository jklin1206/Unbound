import Foundation

/// Local-first routine completion store. The 24h-cooldown + `unbound.gains`
/// LVL XP bump are copied byte-for-byte from the legacy `RoutineCompletionStore`
/// (same UserDefaults keys) so call sites swap with zero behavior change.
/// The records list is persisted as JSON to Application Support; cooldown +
/// gains stay in UserDefaults to guarantee parity.
@MainActor
final class RoutineHistoryStore {
    static let shared = RoutineHistoryStore()

    private let defaults: UserDefaults
    private let fileURL: URL
    private let keyPrefix = "unbound.routineLastCompleted."
    private let gainsKey = "unbound.gains"
    private let cooldown: TimeInterval = 24 * 3600

    private var records: [RoutineCompletionRecord]

    init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        self.defaults = defaults
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("routine-history.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([RoutineCompletionRecord].self, from: data) {
            self.records = decoded
        } else {
            self.records = []
        }
    }

    // MARK: Preserved API (parity with legacy RoutineCompletionStore)

    func canComplete(routineId: String) -> Bool {
        guard let last = lastCompleted(routineId: routineId) else { return true }
        return Date().timeIntervalSince(last) >= cooldown
    }

    func lastCompleted(routineId: String) -> Date? {
        let raw = defaults.double(forKey: keyPrefix + routineId)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    @discardableResult
    func complete(_ routine: RoutineDef) -> Bool {
        guard canComplete(routineId: routine.id) else { return false }
        defaults.set(Date().timeIntervalSince1970, forKey: keyPrefix + routine.id)
        let current = defaults.integer(forKey: gainsKey)
        defaults.set(current + routine.spReward, forKey: gainsKey)
        return true
    }

    // MARK: Added — progression history

    func record(_ rec: RoutineCompletionRecord) {
        records.append(rec)
        persist()
    }

    func history(routineId: String) -> [RoutineCompletionRecord] {
        records.filter { $0.routineId == routineId }
            .sorted { $0.completedAt > $1.completedAt }
    }

    /// `count` of completions + the `best` metric (highest total then fewest
    /// bursts for repCount; shortest seconds for time; most steps for steps).
    func summary(routineId: String) -> (count: Int, best: RoutineMetric?)? {
        let h = history(routineId: routineId)
        guard !h.isEmpty else { return (0, nil) }
        var best: RoutineMetric? = nil
        for m in h.map(\.primaryMetric) {
            if best == nil || betterThan(m, best!) { best = m }
        }
        return (h.count, best)
    }

    /// True if `lhs` is a better result than `rhs` for the same metric kind.
    private func betterThan(_ lhs: RoutineMetric, _ rhs: RoutineMetric) -> Bool {
        switch (lhs, rhs) {
        case (.time(let a), .time(let b)):
            return a < b
        case (.repCount(let at, let ab), .repCount(let bt, let bb)):
            if at != bt { return at > bt }
            return ab.count < bb.count
        case (.steps(let ad, _), .steps(let bd, _)):
            return ad > bd
        default:
            return false
        }
    }

    func clear() {
        records = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
