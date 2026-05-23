import Foundation

// MARK: - AISession
//
// Claude-generated, user-contextualized training session for a single skill.
// Replaces the static `SkillTrainingPlan` lookup at the SkillSessionView entry
// point. Static plans (in `SkillTrainingPlanLibrary`) are still used as
// reference methodology for the 12 keystone skills and as a fallback when the
// API call fails — so the user always gets a workable session.

struct AISession: Codable, Equatable {
    let skillId: String
    let generatedAt: Date

    /// One-line overview, e.g. "Today: pull-up volume + grip strength".
    let summary: String

    /// Honest duration estimate from the model.
    let estimatedDurationMinutes: Int

    /// Ordered list of exercises. Use `isAccessory` to split mains vs optional
    /// supplementary work in the UI.
    let exercises: [AIExercise]

    /// True when this session was AI-generated. False when we fell back to
    /// the static plan / minimal default because the API call failed.
    let isAIGenerated: Bool
}

struct AIExercise: Codable, Equatable, Identifiable {
    /// Matches `TrainingPrescription.id` so the bridge into the legacy
    /// slot-chip UI keys correctly through `loggedSets[rx.id]`.
    var id: String { name + "_\(setsCount)x\(target.displayString)" }

    let name: String
    /// One-sentence plain-language "what is this exercise."
    let description: String
    /// 2-3 short form cues.
    let cues: [String]
    let setsCount: Int
    let target: AIPrescriptionTarget
    let restSeconds: Int
    let notes: String?
    /// Marks supplementary work the user can skip if pressed for time.
    let isAccessory: Bool
}

enum AIPrescriptionTarget: Codable, Equatable {
    case reps(Int)
    case repsRange(Int, Int)
    case amrap
    case hold(seconds: Int)
    case tempo(reps: Int, eccentric: Int, hold: Int, concentric: Int)

    var displayString: String {
        switch self {
        case .reps(let r):                       return "\(r) reps"
        case .repsRange(let lo, let hi):         return "\(lo)–\(hi) reps"
        case .amrap:                             return "AMRAP"
        case .hold(let s):                       return "\(s)s hold"
        case .tempo(let r, let e, let h, let c): return "\(r) reps @ \(e)-\(h)-\(c)"
        }
    }
}

// MARK: - Bridge to existing prescription/UI types
//
// The session view's set-logger sheet renders against `PrescriptionTarget` and
// `TrainingPrescription`. Bridging here keeps the existing logging UI and the
// session-finish XP flow working unchanged — we just feed AI-generated data
// through the same shape.

extension AIPrescriptionTarget {
    var asLegacyTarget: PrescriptionTarget {
        switch self {
        case .reps(let r):                       return .reps(r)
        case .repsRange(let lo, let hi):         return .repsRange(lo, hi)
        case .amrap:                             return .amrap
        case .hold(let s):                       return .hold(seconds: s)
        case .tempo(let r, let e, let h, let c): return .tempo(reps: r, eccentric: e, hold: h, concentric: c)
        }
    }
}

extension AIExercise {
    /// Adapts an AI exercise into the shape the existing slot-chip / set-logger
    /// code expects. The id mirrors the AI exercise id so callers can key
    /// `loggedSets` by it.
    var asLegacyPrescription: TrainingPrescription {
        TrainingPrescription(
            exerciseName: name,
            sets: setsCount,
            target: target.asLegacyTarget,
            restSeconds: restSeconds,
            notes: notes
        )
    }
}
