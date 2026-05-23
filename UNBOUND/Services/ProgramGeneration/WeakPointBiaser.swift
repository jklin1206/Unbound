// UNBOUND/Services/ProgramGeneration/WeakPointBiaser.swift
import Foundation

/// Converts the scan's weak-point signals into generator-usable shapes.
///
/// - `bias(from:)` → FocusArea[] → per-muscle-group integer weights
/// - `pickBiased(...)` → C-bias: pick the candidate whose target groups
///   overlap the biased set (used when the generator has two equivalent
///   exercise options and wants to pick the one that hits a weak point)
/// - `addAccessories(...)` → B-bias: append extra accessory exercises whose
///   target groups overlap the biased set, up to a cap
///
/// Generic over the exercise type — call sites provide a closure to extract
/// target muscle groups. Keeps this module decoupled from ExerciseCatalog.
enum WeakPointBiaser {

    /// FocusArea priority → bias weight. Only priority 1 and 2 produce weight.
    static func bias(from focusAreas: [FocusArea]) -> [MuscleGroup: Int] {
        var result: [MuscleGroup: Int] = [:]
        for fa in focusAreas {
            let weight: Int
            switch fa.priority {
            case 1: weight = 2
            case 2: weight = 1
            default: continue
            }
            result[fa.muscleGroup] = weight
        }
        return result
    }

    /// C-bias: pick the candidate whose target groups overlap the biased set.
    /// Returns nil only when `candidates` is empty. On ties, returns the
    /// last-scored candidate (standard `max(by:)` behavior — doesn't matter
    /// for the caller).
    static func pickBiased<T>(
        candidates: [T],
        biasedGroups: [MuscleGroup: Int],
        biasedGroupsFor: (T) -> [MuscleGroup]
    ) -> T? {
        guard !candidates.isEmpty else { return nil }
        return candidates
            .map { ($0, score(for: $0, biasedGroups: biasedGroups, groupsFor: biasedGroupsFor)) }
            .max(by: { $0.1 < $1.1 })?
            .0
    }

    /// B-bias: append up to `maxAccessories` entries from `pool` that target
    /// biased muscle groups, highest-scoring first. Already-included entries
    /// are excluded.
    static func addAccessories<T: Equatable>(
        to exercises: [T],
        from pool: [T],
        biasedGroups: [MuscleGroup: Int],
        maxAccessories: Int,
        targetGroupsFor: (T) -> [MuscleGroup]
    ) -> [T] {
        guard !biasedGroups.isEmpty, maxAccessories > 0 else { return exercises }

        let ranked = pool
            .filter { !exercises.contains($0) }
            .map { ($0, score(for: $0, biasedGroups: biasedGroups, groupsFor: targetGroupsFor)) }
            .filter { $0.1 > 0 }
            .sorted(by: { $0.1 > $1.1 })

        let toAdd = ranked.prefix(maxAccessories).map(\.0)
        return exercises + Array(toAdd)
    }

    private static func score<T>(
        for value: T,
        biasedGroups: [MuscleGroup: Int],
        groupsFor: (T) -> [MuscleGroup]
    ) -> Int {
        groupsFor(value).reduce(0) { $0 + (biasedGroups[$1] ?? 0) }
    }
}
