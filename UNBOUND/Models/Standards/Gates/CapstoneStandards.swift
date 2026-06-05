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

/// Rotation of Apex (wildcard) hard-workout standards used by the Apex vow slot.
/// WeeklyVowGenerator indexes into this array using week-number-mod-rotation.count
/// so the same workout doesn't repeat within `rotation.count` weeks.
enum PrestigeCapstoneCatalog {

    static let rotation: [WeeklyVowProof] = [
        WeeklyVowProof(
            displayName: "Iron Gauntlet",
            description: "A heavy full-body gauntlet: press, squat, carry, and brace under fatigue.",
            evaluation: .manualClaim
        ),
        WeeklyVowProof(
            displayName: "Engine Breaker",
            description: "A hard conditioning session built around sustained running and loaded breathing.",
            evaluation: .manualClaim
        ),
        WeeklyVowProof(
            displayName: "Pull Crucible",
            description: "A dense upper-body pull session: strict reps, rows, trunk lock, and grip finish.",
            evaluation: .manualClaim
        ),
        WeeklyVowProof(
            displayName: "Static Furnace",
            description: "A control-heavy core session built from holds, bracing, and clean positions.",
            evaluation: .manualClaim
        ),
        WeeklyVowProof(
            displayName: "Impact Ladder",
            description: "A power-output session: jumps, swings, lunges, and loaded carries.",
            evaluation: .manualClaim
        ),
        WeeklyVowProof(
            displayName: "Volume Blackout",
            description: "A high-density bodyweight session with short rests and no skipped movements.",
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
