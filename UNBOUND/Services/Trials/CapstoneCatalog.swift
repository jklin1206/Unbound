// UNBOUND/Services/Trials/CapstoneCatalog.swift
import Foundation

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
        .agility: WeeklyVowProof(
            displayName: "Movement Flow",
            description: "Move through a 3-minute mobility flow without stopping.",
            evaluation: .liveTimer(seconds: 180, exerciseName: "mobility flow")
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
