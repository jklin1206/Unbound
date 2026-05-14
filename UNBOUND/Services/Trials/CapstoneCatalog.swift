// UNBOUND/Services/Trials/CapstoneCatalog.swift
import Foundation

/// Per-axis capstone catalog. One static capstone per AttributeKey, used
/// by Aligned and Growth card slots. The .power capstone uses a dynamically
/// scaled criterion stamped at card-generation time (see TrialGenerator).
enum CapstoneCatalog {

    static let perAxis: [AttributeKey: TrialCapstone] = [
        .power: TrialCapstone(
            displayName: "Top-Set Benchmark",
            description: "Hit a working set above your 4-week best on a Power-axis exercise this weekend.",
            // Placeholder criterion — TrialGenerator overrides with a
            // dynamically scaled criterion at card generation time.
            evaluation: .autoFromLog(.weightKg(0))
        ),
        .agility: TrialCapstone(
            displayName: "Movement Flow",
            description: "Move through a 3-minute mobility flow without stopping.",
            evaluation: .liveTimer(seconds: 180, exerciseName: "mobility flow")
        ),
        .control: TrialCapstone(
            displayName: "Hold Sequence",
            description: "Hold a strict 90-second plank.",
            evaluation: .liveTimer(seconds: 90, exerciseName: "plank")
        ),
        .endurance: TrialCapstone(
            displayName: "Timed Cardio",
            description: "Log a 5K run, row, or bike interval session this weekend.",
            evaluation: .autoFromLog(.variant("run 5k"))
        ),
        .mobility: TrialCapstone(
            displayName: "Deep Squat Hold",
            description: "Sit in a deep squat for 60 seconds without breaking.",
            evaluation: .liveTimer(seconds: 60, exerciseName: "deep squat")
        ),
        .explosiveness: TrialCapstone(
            displayName: "Output Challenge",
            description: "8 max-effort box jumps.",
            evaluation: .autoFromLog(.reps(8, exerciseName: "box jump"))
        )
    ]
}
