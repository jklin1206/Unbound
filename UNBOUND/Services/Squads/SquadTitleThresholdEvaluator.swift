// UNBOUND/Services/Squads/SquadTitleThresholdEvaluator.swift
import Foundation

/// Pure helper: given prior + current counter snapshots, return any new
/// SquadTitleIDs whose thresholds were crossed.
enum SquadTitleThresholdEvaluator {

    struct Counters: Equatable, Sendable {
        var linkedSessionsCount: Int = 0
        var squadStreakWeeks: Int = 0
        var collectiveAxisRankUps: [AttributeKey: Int] = [:]
        var affinityTenureMonths: [AttributeKey: Int] = [:]
    }

    private static let linkedThresholds: [(count: Int, tier: Int)] = [(10, 1), (50, 2), (200, 3)]
    private static let streakThresholds: [(count: Int, tier: Int)] = [(4, 1), (12, 2), (52, 3)]
    private static let axisThresholds:   [(count: Int, tier: Int)] = [(25, 1), (100, 2), (300, 3)]
    private static let tenureThresholds: [(count: Int, tier: Int)] = [(2, 1), (4, 2), (12, 3)]

    static func crossings(prior: Counters, current: Counters) -> [SquadTitleID] {
        var out: [SquadTitleID] = []

        for (threshold, tier) in linkedThresholds where prior.linkedSessionsCount < threshold && current.linkedSessionsCount >= threshold {
            out.append(SquadTitleID(category: .linkedSessions, axis: nil, tier: tier))
        }
        for (threshold, tier) in streakThresholds where prior.squadStreakWeeks < threshold && current.squadStreakWeeks >= threshold {
            out.append(SquadTitleID(category: .squadStreak, axis: nil, tier: tier))
        }
        for axis in AttributeKey.allCases {
            let before = prior.collectiveAxisRankUps[axis] ?? 0
            let after = current.collectiveAxisRankUps[axis] ?? 0
            for (threshold, tier) in axisThresholds where before < threshold && after >= threshold {
                out.append(SquadTitleID(category: .collectiveAxis, axis: axis, tier: tier))
            }
        }
        for axis in AttributeKey.allCases {
            let before = prior.affinityTenureMonths[axis] ?? 0
            let after = current.affinityTenureMonths[axis] ?? 0
            for (threshold, tier) in tenureThresholds where before < threshold && after >= threshold {
                out.append(SquadTitleID(category: .affinityTenure, axis: axis, tier: tier))
            }
        }
        return out
    }
}
