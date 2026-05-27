// UNBOUND/Services/ProgramGeneration/AccessoryBiasRefreshRule.swift
import Foundation

/// Gates whether the next block's accessory bias refreshes from new focus input,
/// or carries forward from the previous block.
///
/// Rule: if the top-2 muscle groups (by bias weight) in the new input match
/// the top-2 of the previous block's bias — and their rank order matches —
/// carry forward. Otherwise refresh.
///
/// This avoids churn when a checkpoint or profile change does not actually
/// change the user's explicit training priorities.
enum AccessoryBiasRefreshRule {

    struct Result: Equatable {
        let bias: [MuscleGroup: Int]
        let carriedForward: Bool
    }

    static func resolve(
        newFocusAreas: [FocusArea],
        previousBlock: ProgramBlock?
    ) -> Result {
        let newBias = WeakPointBiaser.bias(from: newFocusAreas)

        guard let previousBlock else {
            return Result(bias: newBias, carriedForward: false)
        }

        let prevTop2 = topTwo(from: previousBlock.accessoryBias)
        let newTop2 = topTwo(from: newBias)

        if prevTop2 == newTop2 {
            return Result(bias: previousBlock.accessoryBias, carriedForward: true)
        }
        return Result(bias: newBias, carriedForward: false)
    }

    /// Extract the top-2 muscle groups by bias weight, in rank order.
    /// Sort is stable-ish: primary key is weight descending; ties broken by
    /// muscle group raw value ascending so the comparison is deterministic.
    private static func topTwo(from bias: [MuscleGroup: Int]) -> [MuscleGroup] {
        bias
            .sorted(by: { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.rawValue < rhs.key.rawValue
            })
            .prefix(2)
            .map(\.key)
    }
}
