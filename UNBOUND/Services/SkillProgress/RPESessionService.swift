import Foundation
import Observation

// MARK: - RPESessionService
//
// Replaces the LLM-driven AISessionGeneratorService for daily session
// prescription. Daily sessions are deterministic math — there is no
// reason to spend an API call on what is essentially a closed-form
// formula:
//
//   next_load = last_load × (1 + 0.025 × (target_RPE − actual_RPE))
//
// One 2.5% load adjustment per RPE point of headroom. For bodyweight
// sets, rep progression: hit prescribed reps + RPE ≤ 7 → add a rep
// next session; missed prescribed reps → hold.
//
// The service returns `AISession`-shaped results so existing views
// (SkillSessionView et al) keep working unchanged. `isAIGenerated`
// stays false — these prescriptions are authored + math-adjusted, not
// model-written.

@MainActor
@Observable
final class RPESessionService {

    static let shared = RPESessionService()

    /// Default target RPE — "leave 2 reps in reserve." Conservative for
    /// hypertrophy and skill grease, aggressive enough to drive overload.
    static let defaultTargetRPE: Int = 8

    /// 2.5% per RPE point of headroom. Industry standard for autoregulation.
    private static let percentPerRPEPoint: Double = 0.025

    /// Minimum load increment, kg. Sub-2.5 kg adjustments are noise.
    private static let loadStepKg: Double = 2.5

    /// Same-day cache so re-opening the session screen returns the same
    /// prescription. Keyed by `<skillId>.<yyyy-MM-dd>`. Cleared on the
    /// boundary by date check, not eviction.
    private var todayCache: [String: AISession] = [:]

    private let database = DatabaseService.shared
    private var logger: LoggingService { LoggingService.shared }

    private init() {}

    /// Builds today's session for a skill. Reads the authored static plan,
    /// pulls the user's last logged session for this skill, applies RPE
    /// math to each prescription, and returns an `AISession` for the view
    /// layer.
    ///
    /// `forceRefresh` clears the same-day cache and recomputes — useful
    /// when the user just logged a set and wants the next prescription
    /// updated immediately.
    func session(
        forSkillId skillId: String,
        userId: String,
        forceRefresh: Bool = false
    ) async throws -> AISession {
        let cacheKey = todayCacheKey(skillId: skillId)
        if !forceRefresh, let cached = todayCache[cacheKey] {
            return cached
        }

        guard let plan = SkillTrainingPlanLibrary.plan(for: skillId) else {
            throw RPESessionError.noAuthoredPlan(skillId: skillId)
        }

        let lastLog = await fetchLastSessionLog(skillId: skillId, userId: userId)
        let exercises = plan.mainSets.map { rx in
            adjustedExercise(from: rx, lastLog: lastLog, isAccessory: false)
        }
        let accessories = plan.accessories.map { acc in
            AIExercise(
                name: acc.name,
                description: ExerciseExplainerLibrary.description(for: acc.name) ?? "",
                cues: acc.cues,
                setsCount: 2,
                target: .reps(8),
                restSeconds: 60,
                notes: nil,
                isAccessory: true
            )
        }

        let session = AISession(
            skillId: skillId,
            generatedAt: Date(),
            summary: planSummary(skill: plan, lastLog: lastLog),
            estimatedDurationMinutes: estimatedDuration(for: plan),
            exercises: exercises + accessories,
            isAIGenerated: false
        )
        todayCache[cacheKey] = session
        return session
    }

    /// Pre-warms the cache after a goal is added so the user's next
    /// Train tap on that skill renders instantly.
    func prefetch(skillId: String, userId: String) async {
        _ = try? await session(forSkillId: skillId, userId: userId)
    }

    // MARK: - Adjustment math

    /// Builds an `AIExercise` from a static prescription, augmented with
    /// last-session context if available. Notes carry the human-readable
    /// summary so the user can see what changed and why.
    private func adjustedExercise(
        from rx: TrainingPrescription,
        lastLog: SessionLog?,
        isAccessory: Bool
    ) -> AIExercise {
        let lastEx = lastLog?.exercises.first(where: { $0.name == rx.exerciseName })
        let target = aiTarget(from: rx.target)
        let summary = buildExerciseNotes(rx: rx, lastEx: lastEx)

        return AIExercise(
            name: rx.exerciseName,
            description: ExerciseExplainerLibrary.description(for: rx.exerciseName) ?? "",
            cues: ExerciseExplainerLibrary.cues(for: rx.exerciseName, fallback: []),
            setsCount: rx.sets,
            target: target,
            restSeconds: rx.restSeconds,
            notes: summary,
            isAccessory: isAccessory
        )
    }

    /// Translates the authored PrescriptionTarget into the AIExercise's
    /// AIPrescriptionTarget shape. Tempo + repsRange collapse to their
    /// midpoint for the session-screen UI; the static plan's note carries
    /// the nuance.
    private func aiTarget(from target: PrescriptionTarget) -> AIPrescriptionTarget {
        switch target {
        case .reps(let r): return .reps(r)
        case .repsRange(let lo, let hi): return .reps((lo + hi) / 2)
        case .amrap: return .amrap
        case .hold(let s): return .hold(seconds: s)
        case .tempo(let r, _, _, _): return .reps(r)
        }
    }

    /// Composes the prescription's note with last-session context.
    /// Format: "Last: 8/8/6 reps @ RPE 7. Try 9/9/7." or for weighted:
    /// "Last: 5x65kg @ RPE 6. Bump to 67.5kg."
    private func buildExerciseNotes(rx: TrainingPrescription, lastEx: LoggedExercise?) -> String? {
        var parts: [String] = []
        if let note = rx.notes, !note.isEmpty { parts.append(note) }
        guard let lastEx, !lastEx.sets.isEmpty else {
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }

        let lastSummary = summarize(sets: lastEx.sets)
        let suggestion = suggestNextLoad(sets: lastEx.sets)
        var lastBlock = "Last: \(lastSummary)"
        if let suggestion {
            lastBlock += " — \(suggestion)"
        }
        parts.append(lastBlock)
        return parts.joined(separator: " · ")
    }

    /// Compact text summary of the last session's sets — reps, optional
    /// weight, optional RPE. Examples:
    ///   "8/8/6 reps @ RPE 7"
    ///   "5×65kg @ RPE 6"
    ///   "30s/25s/20s holds"
    private func summarize(sets: [LoggedSet]) -> String {
        let isHold = sets.allSatisfy { $0.holdSeconds != nil }
        if isHold {
            let parts = sets.map { "\($0.holdSeconds ?? 0)s" }.joined(separator: "/")
            return "\(parts) holds"
        }

        let reps = sets.map { "\($0.reps)" }.joined(separator: "/")
        let firstWeight = sets.first?.weightKg
        let weightSuffix: String = {
            guard let w = firstWeight, w > 0 else { return " reps" }
            return "×\(formatKg(w))"
        }()

        let rpes = sets.compactMap(\.rpe)
        let avgRPE: Int? = {
            guard !rpes.isEmpty else { return nil }
            return Int((Double(rpes.reduce(0, +)) / Double(rpes.count)).rounded())
        }()
        if let avgRPE {
            return "\(reps)\(weightSuffix) @ RPE \(avgRPE)"
        }
        return "\(reps)\(weightSuffix)"
    }

    /// Computes the "next session" suggestion based on RPE math. Returns
    /// nil for bodyweight sets without RPE (no signal to act on) so we
    /// don't overpromise progressive overload.
    private func suggestNextLoad(sets: [LoggedSet]) -> String? {
        // Use the heaviest top set as the anchor for adjustment.
        guard let topSet = sets.max(by: { (a, b) in
            (a.weightKg ?? 0) < (b.weightKg ?? 0)
        }) else { return nil }

        guard let rpe = topSet.rpe else { return nil }
        let target = Self.defaultTargetRPE
        let delta = target - rpe

        if let weight = topSet.weightKg, weight > 0 {
            // Weighted: percent-based load adjustment.
            let factor = 1.0 + Self.percentPerRPEPoint * Double(delta)
            let raw = weight * factor
            let stepped = (raw / Self.loadStepKg).rounded() * Self.loadStepKg
            if stepped == weight { return "hold load" }
            let direction = stepped > weight ? "bump to" : "drop to"
            return "\(direction) \(formatKg(stepped))"
        } else {
            // Bodyweight: rep progression. RPE ≤ 7 with target reps hit
            // → add a rep. Otherwise hold.
            if delta >= 1 {
                return "add 1 rep"
            }
            if delta <= -1 {
                return "hold reps"
            }
            return nil
        }
    }

    private func formatKg(_ kg: Double) -> String {
        if kg == floor(kg) { return "\(Int(kg))kg" }
        return String(format: "%.1fkg", kg)
    }

    // MARK: - Persistence reads

    private func fetchLastSessionLog(skillId: String, userId: String) async -> SessionLog? {
        do {
            let logs: [SessionLog] = try await database.query(
                collection: "sessionLogs",
                field: "skillId",
                isEqualTo: skillId,
                orderBy: "createdAt",
                descending: true,
                limit: 5
            )
            return logs.first(where: { $0.userId == userId })
        } catch {
            logger.log(
                "RPESessionService: failed to read last session: \(error.localizedDescription)",
                level: .warning
            )
            return nil
        }
    }

    // MARK: - Helpers

    private func planSummary(skill: SkillTrainingPlan, lastLog: SessionLog?) -> String {
        let setsCount = skill.mainSets.reduce(0) { $0 + $1.sets }
        if let last = lastLog {
            let days = max(1, Calendar.current.dateComponents([.day], from: last.createdAt, to: Date()).day ?? 1)
            return "\(setsCount) working sets · \(days)d since last session — RPE-tuned to your last log."
        }
        return "\(setsCount) working sets · first session — log RPE for next-session overload."
    }

    private func estimatedDuration(for plan: SkillTrainingPlan) -> Int {
        let mainSeconds = plan.mainSets.reduce(0) { acc, rx in
            acc + (rx.sets * 45) + (rx.sets * rx.restSeconds)
        }
        let accessorySeconds = plan.accessories.count * 240
        return max(15, (mainSeconds + accessorySeconds) / 60)
    }

    private func todayCacheKey(skillId: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "\(skillId).\(fmt.string(from: Date()))"
    }
}

enum RPESessionError: LocalizedError {
    case noAuthoredPlan(skillId: String)

    var errorDescription: String? {
        switch self {
        case .noAuthoredPlan(let id):
            return "No authored training plan for skill \(id) — log a set instead."
        }
    }
}
