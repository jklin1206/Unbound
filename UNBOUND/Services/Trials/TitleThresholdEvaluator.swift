// UNBOUND/Services/Trials/TitleThresholdEvaluator.swift
import Foundation

/// Pure helper: compare two TrialsState snapshots and return any TitleIDs
/// whose 3 / 7 / 15 thresholds were crossed.
enum TitleThresholdEvaluator {

    /// Thresholds in ascending order with their tier label.
    private static let thresholds: [(count: Int, tier: TitleID.Tier)] = [
        (3, .bronze),
        (7, .silver),
        (15, .gold)
    ]

    static func crossings(prior: TrialsState, current: TrialsState) -> [TitleID] {
        var result: [TitleID] = []

        // Axis paths
        for axis in AttributeKey.allCases {
            let before = prior.completionsByAxis[axis] ?? 0
            let after = current.completionsByAxis[axis] ?? 0
            for (threshold, tier) in thresholds where before < threshold && after >= threshold {
                result.append(TitleID(path: .axis(axis), tier: tier))
            }
        }

        // Card-kind paths
        for kind in TrialCardKind.allCases {
            let before = prior.completionsByCardKind[kind] ?? 0
            let after = current.completionsByCardKind[kind] ?? 0
            for (threshold, tier) in thresholds where before < threshold && after >= threshold {
                result.append(TitleID(path: .cardKind(kind), tier: tier))
            }
        }

        return result
    }
}
