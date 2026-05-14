// UNBOUND/Services/Trials/PrestigeCapstoneCatalog.swift
import Foundation

/// Rotation of prestige (wildcard) capstones used by the Prestige card slot.
/// TrialGenerator indexes into this array using week-number-mod-rotation.count
/// so the same prestige doesn't repeat within `rotation.count` weeks.
enum PrestigeCapstoneCatalog {

    static let rotation: [TrialCapstone] = [
        TrialCapstone(
            displayName: "Max Pull-Up AMRAP",
            description: "One AMRAP set of pull-ups, 15+ reps unbroken.",
            evaluation: .autoFromLog(.reps(15, exerciseName: "pullup"))
        ),
        TrialCapstone(
            displayName: "Broad Jump Distance",
            description: "Hit a personal-best broad jump this weekend.",
            evaluation: .manualClaim
        ),
        TrialCapstone(
            displayName: "1-Rep PR Attempt",
            description: "Hit a 1-rep PR on bench, squat, deadlift, or overhead press.",
            // Placeholder — TrialGenerator stamps a dynamically scaled criterion.
            evaluation: .autoFromLog(.weightKg(0))
        ),
        TrialCapstone(
            displayName: "Strict Muscle-Up",
            description: "One strict muscle-up. No kip, no swing.",
            evaluation: .autoFromLog(.variant("strict muscle-up"))
        ),
        TrialCapstone(
            displayName: "L-Sit Hold",
            description: "20-second strict L-sit hold.",
            evaluation: .liveTimer(seconds: 20, exerciseName: "l-sit")
        ),
        TrialCapstone(
            displayName: "5K Sub-25",
            description: "Log a 5K under 25 minutes.",
            evaluation: .manualClaim
        )
    ]

    /// Pick a capstone for a given ISO week number. Modulo over the rotation
    /// length guarantees a 6-week minimum gap between repeats.
    static func capstone(for weekNumber: Int) -> TrialCapstone {
        let idx = ((weekNumber % rotation.count) + rotation.count) % rotation.count
        return rotation[idx]
    }
}
