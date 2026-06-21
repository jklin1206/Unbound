// UNBOUND/Services/Trials/VowBadgeTrack.swift
import Foundation

enum VowBadgeTrack {
    struct Milestone: Equatable, Sendable { let threshold: Int }
    struct Progress: Equatable, Sendable {
        let current: Int
        let nextThreshold: Int?
    }
    /// Tunable milestone thresholds (spec §8).
    static let thresholds = [5, 15, 30, 52]

    static func totalKept(_ byLane: [VowLane: Int]) -> Int { byLane.values.reduce(0, +) }

    static func crossings(priorKept: Int, currentKept: Int) -> [Milestone] {
        thresholds.filter { priorKept < $0 && currentKept >= $0 }.map { Milestone(threshold: $0) }
    }

    static func progress(totalKept: Int) -> Progress {
        Progress(current: totalKept, nextThreshold: thresholds.first { $0 > totalKept })
    }
}
