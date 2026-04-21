// UNBOUND/Services/ProgramGeneration/ExerciseEquipmentClassifier.swift
import Foundation

/// Coarse equipment category inferred from an exercise's canonical name.
/// Used by the program generator to filter the catalog to exercises the
/// user can actually perform with the equipment they have.
///
/// `CatalogExercise` has no explicit equipment tag field — keyword matching
/// against the canonical exercise name is the pragmatic MVP. If a specific
/// exercise mis-classifies, extend the keyword list below.
enum ExerciseEquipmentCategory: String {
    case barbell       // needs a barbell (+ rack for squat/bench)
    case dumbbell      // needs dumbbells (or light accessory equivalents)
    case machine       // needs cables / selectorized machines (gym)
    case bodyweight    // only body + optional pullup bar / dip station
}

enum ExerciseEquipmentClassifier {

    /// Infer the equipment category from the exercise's canonical name.
    static func classify(_ exerciseName: String) -> ExerciseEquipmentCategory {
        let n = exerciseName.lowercased()

        // Bodyweight keywords (check first — "bodyweight squat" should not
        // match "squat" → barbell).
        let bodyweightKeywords = [
            "bodyweight", "pullup", "pull-up", "pull up",
            "chin-up", "chinup", "chin up",
            "pushup", "push-up", "push up",
            "dip", "handstand", "hanging", "plank",
            "pistol squat", "shrimp squat", "assisted pistol",
            "muscle up", "muscle-up", "muscleup",
            "l-sit", "lsit", "l sit",
            "bodyweight row", "inverted row",
            "hollow body", "leg raise", "jump squat",
            "bulgarian split squat", "walking lunge", "step up"
        ]
        if bodyweightKeywords.contains(where: { n.contains($0) }) {
            return .bodyweight
        }

        // Barbell keywords.
        let barbellKeywords = [
            "barbell", "back squat", "front squat", "safety bar squat",
            "deadlift", "romanian deadlift", "rdl",
            "good morning", "bench press", "incline bench press",
            "overhead press", "ohp", "military press", "push press",
            "clean", "snatch", "power clean", "hang clean",
            "floor press"
        ]
        if barbellKeywords.contains(where: { n.contains($0) }) {
            return .barbell
        }

        // Machine / cable.
        let machineKeywords = [
            "machine", "cable", "leg press", "hack squat",
            "lat pulldown", "pulldown", "seated row", "cable row",
            "cable fly", "pec deck", "leg extension", "leg curl",
            "calf machine", "preacher curl machine"
        ]
        if machineKeywords.contains(where: { n.contains($0) }) {
            return .machine
        }

        // Dumbbell / accessory (explicit "dumbbell"/"db" plus obvious holds).
        let dumbbellKeywords = [
            "dumbbell", "db ",
            "goblet squat"
        ]
        if dumbbellKeywords.contains(where: { n.contains($0) }) {
            return .dumbbell
        }

        // Default: dumbbell (middle-ground accessory assumption — works
        // with minimal free weights).
        return .dumbbell
    }

    /// True if the exercise is compatible with the user's training style AND
    /// equipment chips. Style is the hard filter (bodyweight users never get
    /// barbells); equipment is the physical-availability filter.
    ///
    /// Granular Equipment chips map roughly to:
    /// - `.fullGym`     → trumps everything (barbell + dumbbells + machines + bodyweight)
    /// - `.machines`    → cables / selectorized machines
    /// - `.barbell`     → barbell + rack
    /// - `.dumbbells`   → dumbbells
    /// - `.bench`       → bench (pairs with dumbbells for press work)
    /// - `.pullupBar`   → bodyweight pull/hang work (covered by bodyweight category)
    /// - `.bodyweight`  → bodyweight only
    /// - `.bands`       → light-resistance proxy (treated as dumbbell cat for accessories)
    /// - `.homeWeights` → legacy catch-all = dumbbells + bench + (likely) barbell + bodyweight
    static func isCompatible(
        exerciseName: String,
        style: TrainingStyle,
        userEquipment: [Equipment]
    ) -> Bool {
        let category = classify(exerciseName)

        // Hard style gate: bodyweight style rejects everything non-bodyweight.
        if style == .bodyweight && category != .bodyweight {
            return false
        }

        // Bodyweight work is always acceptable — every user has a body.
        if category == .bodyweight {
            return true
        }

        // Full gym trumps everything else.
        if userEquipment.contains(.fullGym) {
            return true
        }

        // homeWeights is a legacy catch-all = dumbbells + bench + bodyweight
        // (and generally a barbell home setup).
        let hasHomeWeights = userEquipment.contains(.homeWeights)

        switch category {
        case .bodyweight:
            return true // handled above, kept for exhaustiveness.
        case .barbell:
            return userEquipment.contains(.barbell)
                || hasHomeWeights  // legacy: homeWeights implies barbell
        case .dumbbell:
            return userEquipment.contains(.dumbbells)
                || userEquipment.contains(.bench)
                || hasHomeWeights
                || userEquipment.contains(.bands)  // bands substitute for accessory-style dumbbell work
        case .machine:
            return userEquipment.contains(.machines)
        }
    }
}
