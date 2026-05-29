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
// plateaus and, when a deload is warranted, applies DeloadPlanner.planDeload and
// persists — so the next generated/resolved day is a deload with no Coach tap.
//
// Anti-thrash: it never re-deloads an athlete already in a deload block, so a
// run of plateaued sessions can't trap them in a perpetual deload or fight a
// Coach-initiated one.

@MainActor
final class AutoDeloadService {
    static let shared = AutoDeloadService()

    private let store = ProgressionStateStore.shared
    private let detector = PlateauDetector.shared
    private let planner = DeloadPlanner.shared
    private let logger = LoggingService.shared

    private init() {}

    /// Pure decision: deloaded states to persist, or nil when no deload is due.
    /// Skips when already in a deload block (anti-thrash).
    static func plan(states: [ProgressionState], plateauCount: Int) -> [ProgressionState]? {
        guard !states.contains(where: { $0.blockType == .deload }) else { return nil }
        guard DeloadPlanner.shared.shouldDeload(states: states, plateauCount: plateauCount) else { return nil }
        return DeloadPlanner.shared.planDeload(for: states)
    }

    /// Detect plateaus and auto-apply a deload if warranted. Returns whether a
    /// deload fired. Safe to call on every logged session.
    @discardableResult
    func evaluate(userId: String) async -> Bool {
        let states = await store.fetchAll(userId: userId)
        guard !states.isEmpty else { return false }

        let plateaus = await detector.detect(userId: userId, states: states)
        guard let deloaded = Self.plan(states: states, plateauCount: plateaus.count) else { return false }

        for state in deloaded {
            await store.save(state)
        }
        logger.log(
            "AutoDeloadService: auto-deload fired (\(plateaus.count) plateaus, \(deloaded.count) lifts)",
            level: .info
        )
        return true
    }
}
