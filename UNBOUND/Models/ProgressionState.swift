import Foundation

// MARK: - ProgressionState
//
// Per-user-per-exercise progression tracker. The ProgressionEngine writes
// this on every WorkoutLog save. Views (home, session, coach context)
// read it to render current working weights, rep targets, and block info.
//
// Persisted via DatabaseService (local JSON for V1, mirrored to Supabase
// `progression_states` when auth is established).

enum BlockType: String, Codable {
    case accumulation      // weeks 1-4: volume emphasis, RPE 7
    case intensification   // weeks 5-8: moderate volume, RPE 8
    case realization       // weeks 9-11: low volume, heavy, RPE 9 — gated at B-
    case peaking           // week 12 pre-PR: singles/doubles, RPE 9-9.5 — gated at A-
    case deload            // week 12 or as-needed: 60-70% volume

    var displayName: String {
        switch self {
        case .accumulation:    return "Accumulation"
        case .intensification: return "Intensification"
        case .realization:     return "Realization"
        case .peaking:         return "Peaking"
        case .deload:          return "Deload"
        }
    }

    /// Target RPE as an integer (rounded down) — used by existing code
    /// paths. `targetRPERange` gives the finer-grained tuple.
    var targetRPE: Int {
        switch self {
        case .accumulation:    return 7
        case .intensification: return 8
        case .realization:     return 9
        case .peaking:         return 9
        case .deload:          return 6
        }
    }

    /// Finer RPE window per block. Peaking pushes to 9.5 singles.
    var targetRPERange: ClosedRange<Double> {
        switch self {
        case .accumulation:    return 6.5...7.5
        case .intensification: return 7.5...8.5
        case .realization:     return 8.5...9.0
        case .peaking:         return 9.0...9.5
        case .deload:          return 5.5...6.5
        }
    }

    /// Minimum archetype aggregate rank required to include this block in
    /// a generated program. Blocks below the threshold fall back to
    /// accumulation/intensification/deload rotation.
    var unlockRequirement: SubRank? {
        switch self {
        case .realization: return .bMinus
        case .peaking:     return .aMinus
        default:           return nil
        }
    }
}

struct ProgressionState: Codable, Identifiable, Sendable {
    /// "{userId}:{exerciseName}" — stable composite key for storage.
    var id: String { "\(userId):\(exerciseKey)" }

    let userId: String
    /// Lowercase-trimmed exercise name; single source of truth for matching.
    /// e.g. "bench press", "deadlift", "pullup".
    var exerciseKey: String
    var displayName: String

    /// Current working weight in kg. 0 for bodyweight-only movements.
    var currentWorkingWeightKg: Double

    /// Rep range — e.g. 6...8 for strength, 8...12 for hypertrophy.
    var targetRepMin: Int
    var targetRepMax: Int

    /// Target RPE (derived from blockType but stored for override scenarios).
    var targetRPE: Int

    /// How many sessions in a row the athlete has hit the top of the rep
    /// range at target RPE. Weight bumps trigger at 2.
    var consecutiveSessionsAtTarget: Int

    /// Most recent date the working weight was auto-bumped by the engine.
    var lastBumpDate: Date?

    var blockType: BlockType
    /// 1-indexed week within the current block (1-4 for accum/intens, 1-3 for realization, 1 for deload).
    var weekInBlock: Int

    var updatedAt: Date

    // MARK: Convenience

    var targetRepRange: ClosedRange<Int> { targetRepMin...targetRepMax }

    /// Classification of this exercise for weight-bump increments.
    var classification: ExerciseClassification {
        ExerciseClassification.classify(exerciseKey: exerciseKey)
    }

    // MARK: Factory

    static func seed(
        userId: String,
        exercise: String,
        startingWeightKg: Double,
        block: BlockType = .accumulation,
        weekInBlock: Int = 1
    ) -> ProgressionState {
        let normalized = exercise.trimmingCharacters(in: .whitespaces).lowercased()
        let classification = ExerciseClassification.classify(exerciseKey: normalized)
        let repRange = classification.defaultRepRange(for: block)
        return ProgressionState(
            userId: userId,
            exerciseKey: normalized,
            displayName: exercise.capitalized,
            currentWorkingWeightKg: startingWeightKg,
            targetRepMin: repRange.lowerBound,
            targetRepMax: repRange.upperBound,
            targetRPE: block.targetRPE,
            consecutiveSessionsAtTarget: 0,
            lastBumpDate: nil,
            blockType: block,
            weekInBlock: weekInBlock,
            updatedAt: Date()
        )
    }
}

// MARK: - ExerciseClassification

enum ExerciseClassification: String, Codable {
    case upperCompound   // bench, overhead press, weighted pullup
    case lowerCompound   // squat, deadlift, front squat, RDL
    case accessory       // curls, lateral raises, face pulls, etc.
    case bodyweightSkill // pullup, dip, pushup, L-sit — bw progressions

    /// Keyword-matched classification. Any exercise not explicitly matched
    /// falls through to `.accessory`.
    static func classify(exerciseKey key: String) -> ExerciseClassification {
        let normalized = MovementCatalog.normalized(key)

        if isBodyweightProgression(key: key, normalized: normalized) {
            return .bodyweightSkill
        }

        let upperCompoundKeywords = [
            "bench press", "bench", "overhead press", "ohp", "military press",
            "weighted pullup", "weighted chin", "weighted dip",
            "chest press", "shoulder press", "plate loaded", "hammer strength",
            "machine row", "t-bar row", "landmine row", "pulldown"
        ]
        let lowerCompoundKeywords = [
            "back squat", "front squat", "squat",
            "deadlift", "romanian deadlift", "rdl",
            "clean", "snatch", "leg press", "hack squat", "pendulum squat",
            "v-squat", "belt squat", "hip thrust", "back extension",
            "reverse hyper"
        ]
        let bodyweightKeywords = [
            "pullup", "pull-up", "chin-up", "chinup",
            "pushup", "push-up", "dip",
            "bodyweight squat", "cossack squat", "pistol squat", "shrimp squat",
            "l-sit", "lsit", "plank", "dragon flag",
            "dead hang", "muscle-up", "muscle up",
            "hanging knee raise", "hanging leg raise",
            "hollow hold", "hollow rock", "ab wheel", "front lever", "back lever",
            "walking lunge"
        ]

        if !normalized.contains("weighted"),
           bodyweightKeywords.contains(where: { normalized.contains(MovementCatalog.normalized($0)) }) {
            return .bodyweightSkill
        }
        if upperCompoundKeywords.contains(where: { normalized.contains($0) }) {
            return .upperCompound
        }
        if lowerCompoundKeywords.contains(where: { normalized.contains($0) }) {
            return .lowerCompound
        }
        return .accessory
    }

    private static func isBodyweightProgression(key: String, normalized: String) -> Bool {
        guard !normalized.contains("weighted") else { return false }
        guard let definition = MovementCatalog.canonicalExercise(named: key) else { return false }

        switch definition.rankTemplate {
        case .bodyweightReps, .holdControl:
            return true
        case .weightedBodyweight:
            return false
        default:
            break
        }

        if definition.blockKind == .bodyweight {
            return true
        }

        let loadedEquipment: Set<MovementEquipment> = [
            .barbell, .dumbbell, .kettlebell, .cable, .machine,
            .smithMachine, .sled, .cardioMachine
        ]
        let required = Set(definition.equipment)
        return definition.progressionFamily != nil && required.isDisjoint(with: loadedEquipment)
    }

    /// Default rep range per block. Hypertrophy ranges tighten as we push
    /// toward realization and peaking blocks.
    func defaultRepRange(for block: BlockType) -> ClosedRange<Int> {
        switch (self, block) {
        case (.upperCompound, .accumulation):    return 8...10
        case (.upperCompound, .intensification): return 6...8
        case (.upperCompound, .realization):     return 3...5
        case (.upperCompound, .peaking):         return 1...3
        case (.lowerCompound, .accumulation):    return 8...10
        case (.lowerCompound, .intensification): return 5...8
        case (.lowerCompound, .realization):     return 3...5
        case (.lowerCompound, .peaking):         return 1...3
        case (.bodyweightSkill, _):              return 5...12
        case (.accessory, .peaking):             return 6...10
        case (.accessory, _):                    return 10...15
        case (_, .deload):                       return 6...8
        }
    }
}

// MARK: - ProgressionAdvance event
//
// Published by ProgressionEngine when a weight bump lands. Views subscribe
// to trigger the celebratory toast on the home dashboard.

struct ProgressionAdvance: Identifiable {
    let id = UUID()
    let userId: String
    let exerciseKey: String
    let displayName: String
    let previousWeightKg: Double
    let newWeightKg: Double
    let classification: ExerciseClassification
    let at: Date

    var incrementKg: Double { newWeightKg - previousWeightKg }
}

extension Notification.Name {
    static let progressionAdvanced = Notification.Name("unbound.progressionAdvanced")
    static let tierUnlocked = Notification.Name("unbound.tierUnlocked")
}

// MARK: - ProgressionFamilyState — per-user tier unlocks
//
// Chunk 2B. Tracks the highest-unlocked tier + currently-trained tier for
// each progression family (push / pull / legs-single / core-lever). The
// engine auto-unlocks the next tier when the user hits the criterion on
// the current tier's exercise.

struct ProgressionFamilyState: Codable, Sendable, Identifiable {
    var id: String { "\(userId):\(family)" }
    let userId: String
    let family: String
    var unlockedTier: Int
    var currentTier: Int
    var updatedAt: Date
}

struct TierUnlock: Identifiable {
    let id = UUID()
    let userId: String
    let family: String
    let newTier: Int
    let exerciseName: String
    let at: Date
}
