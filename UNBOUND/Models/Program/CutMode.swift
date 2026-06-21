// UNBOUND/Models/CutMode.swift
import Foundation

struct CutMode: Codable, Equatable {
    var enabled: Bool
    var startedAt: Date?
    var softCapWeeks: Int

    init(enabled: Bool = false, startedAt: Date? = nil, softCapWeeks: Int = 8) {
        self.enabled = enabled
        self.startedAt = startedAt
        self.softCapWeeks = softCapWeeks
    }

    /// True once the cut has been active longer than `softCapWeeks`. Used to
    /// surface the "consider a maintenance break" banner without forcing an end.
    func softCapReached(now: Date = Date()) -> Bool {
        guard enabled, let startedAt else { return false }
        let weeksElapsed = now.timeIntervalSince(startedAt) / (7 * 86400)
        return weeksElapsed > Double(softCapWeeks)
    }
}
