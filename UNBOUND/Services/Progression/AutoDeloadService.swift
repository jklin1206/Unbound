import Foundation

// MARK: - AutoDeloadService
//
// Closes the "auto-deload never fires" loop. DeloadPlanner.shouldDeload was
// dead code and planDeload only ran from a manual Coach tap
// (CoachActionExecutor.insertDeload / CoachModesStrip). The phase engine would
// *say* "deload" in copy, but the actual ProgressionState prescriptions were
// never deloaded unless the user tapped Coach.
//
// This runs automatically at the end of post-log progression ingest: it detects
// plateaus and, when a deload is warranted, applies DeloadPlanner.planDeload to
// ONLY the plateaued exercises and persists — so the next generated/resolved day
// deloads those lifts with no Coach tap, leaving progressing lifts untouched.
//
// Anti-thrash is per-exercise and self-healing: it never re-deloads a lift
// already in a deload (that lift exits on its own after
// DeloadPolicy.sessionsInDeload sessions, see ProgressionEngine), and it skips
// lifts inside the post-deload cooldown. Once deloads exit and cooldowns lapse,
// evaluation resumes normally — nothing gets trapped in a perpetual deload.

@MainActor
final class AutoDeloadService {
    static let shared = AutoDeloadService()

    private let store = ProgressionStateStore.shared
    private let detector = PlateauDetector.shared
    private let planner = DeloadPlanner.shared
    private let logger = LoggingService.shared

    private init() {}

    /// Pure decision: the deloaded states to persist, or nil when no deload is
    /// due. Scoped and self-healing — only the freshly-plateaued exercises are
    /// candidates, and a candidate already in a deload or inside its post-deload
    /// cooldown is excluded (the detector already filters cooldowns; the filter
    /// here is defensive). The systemic threshold is measured against the
    /// candidate count, so a lone stall never drags the whole table into deload.
    static func plan(
        states: [ProgressionState],
        plateauedKeys: Set<String>
    ) -> [ProgressionState]? {
        let candidates = states.filter { state in
            plateauedKeys.contains(state.exerciseKey)
                && state.blockType != .deload
                && (state.deloadCooldownRemaining ?? 0) == 0
        }
        guard DeloadPlanner.shared.shouldDeload(plateauCount: candidates.count) else { return nil }
        return DeloadPlanner.shared.planDeload(for: candidates)
    }

    /// Detect plateaus and auto-apply a scoped deload if warranted. Returns
    /// whether a deload fired. Safe to call on every logged session.
    @discardableResult
    func evaluate(userId: String) async -> Bool {
        let states = await store.fetchAll(userId: userId)
        guard !states.isEmpty else { return false }

        let plateaus = await detector.detect(userId: userId, states: states)
        let plateauedKeys = Set(plateaus.map(\.exerciseKey))
        guard let deloaded = Self.plan(states: states, plateauedKeys: plateauedKeys) else { return false }

        for state in deloaded {
            await store.save(state)
        }
        logger.log(
            "AutoDeloadService: scoped auto-deload fired (\(plateaus.count) plateaus, \(deloaded.count) lifts deloaded)",
            level: .info
        )
        return true
    }
}
