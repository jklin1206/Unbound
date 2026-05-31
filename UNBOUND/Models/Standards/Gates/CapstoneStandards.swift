// UNBOUND/Models/Standards/Gates/CapstoneStandards.swift
import Foundation

// MARK: - Capstone gate standards
//
// Per-axis and Apex (wildcard) capstone PROOF targets used by Weekly Vows.
// These are pass/fail GATES, not rank standards — relocated under
// Models/Standards/Gates/ (audit Q2) so every threshold/criterion the app
// gates on lives in one place. The enum names are unchanged; consumers
// (TrialGenerator, WeeklyVowGenerator) reference them as before.

/// Per-axis proof catalog. One static proof per AttributeKey, used by
/// Weekly Vows. The .power proof uses a dynamically scaled criterion stamped
/// at card-generation time.
enum CapstoneCatalog {

    static let perAxis: [AttributeKey: WeeklyVowProof] = [
        .power: WeeklyVowProof(
            displayName: "Top-Set Benchmark",
            description: "Hit a working set above your 4-week best on a Power-axis exercise.",
            // Placeholder criterion: WeeklyVowGenerator overrides with a
            // dynamically scaled criterion at card generation time.
            evaluation: .autoFromLog(.weightKg(0))
        ),
        .vitality: WeeklyVowProof(
            displayName: "Recovery Check-In",
            description: "Complete a 3-minute recovery check-in without skipping the timer.",
            evaluation: .liveTimer(seconds: 180, exerciseName: "recovery check-in")
        ),
        .control: WeeklyVowProof(
            displayName: "Hold Sequence",
            description: "Hold a strict 90-second plank.",
            evaluation: .liveTimer(seconds: 90, exerciseName: "plank")
        ),
        .endurance: WeeklyVowProof(
            displayName: "Timed Cardio",
            description: "Log a 5K run, row, or bike interval session.",
            evaluation: .autoFromLog(.variant("run 5k"))
        ),
        .mobility: WeeklyVowProof(
            displayName: "Deep Squat Hold",
            description: "Sit in a deep squat for 60 seconds without breaking.",
            evaluation: .liveTimer(seconds: 60, exerciseName: "deep squat")
        ),
        .explosiveness: WeeklyVowProof(
            displayName: "Output Proof",
            description: "8 max-effort box jumps.",
            evaluation: .autoFromLog(.reps(8, exerciseName: "box jump"))
        )
    ]
}

/// Rotation of Apex (wildcard) proofs used by the Apex vow slot.
/// WeeklyVowGenerator indexes into this array using week-number-mod-rotation.count
/// so the same proof doesn't repeat within `rotation.count` weeks.
enum PrestigeCapstoneCatalog {

    static let rotation: [WeeklyVowProof] = [
        WeeklyVowProof(
            displayName: "Max Pull-Up AMRAP",
            description: "One AMRAP set of pull-ups, 15+ reps unbroken.",
            evaluation: .autoFromLog(.reps(15, exerciseName: "pullup"))
        ),
        WeeklyVowProof(
            displayName: "Broad Jump Distance",
            description: "Hit a personal-best broad jump.",
            evaluation: .manualClaim
        ),
        WeeklyVowProof(
            displayName: "1-Rep PR Attempt",
            description: "Hit a 1-rep PR on bench, squat, deadlift, or overhead press.",
            // Placeholder: WeeklyVowGenerator stamps a dynamically scaled criterion.
            evaluation: .autoFromLog(.weightKg(0))
        ),
        WeeklyVowProof(
            displayName: "Strict Muscle-Up",
            description: "One strict muscle-up. No kip, no swing.",
            evaluation: .autoFromLog(.variant("strict muscle-up"))
        ),
        WeeklyVowProof(
            displayName: "L-Sit Hold",
            description: "20-second strict L-sit hold.",
            evaluation: .liveTimer(seconds: 20, exerciseName: "l-sit")
        ),
        WeeklyVowProof(
            displayName: "5K Sub-25",
            description: "Log a 5K under 25 minutes.",
            evaluation: .manualClaim
        )
    ]

    /// Pick a capstone for a given ISO week number. Modulo over the rotation
    /// length guarantees a 6-week minimum gap between repeats.
    static func capstone(for weekNumber: Int) -> WeeklyVowProof {
        let idx = ((weekNumber % rotation.count) + rotation.count) % rotation.count
        return rotation[idx]
    }
}
