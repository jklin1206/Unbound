import Foundation

struct AppliedCoachAction: Identifiable, Hashable {
    let id: UUID
    let action: CoachAction
    let appliedAt: Date
}

@MainActor
final class CoachActionExecutor: ObservableObject {
    static let shared = CoachActionExecutor()

    @Published private(set) var undoStack: [AppliedCoachAction] = []
    @Published private(set) var history: [AppliedCoachAction] = []

    private let progressionStore = ProgressionStateStore.shared
    private let preferenceService = ExercisePreferenceService.shared
    private let analytics = AnalyticsService.shared
    private let logger = LoggingService.shared
    private let maxUndo = 5
    private let undoWindow: TimeInterval = 5 * 60

    private init() {}

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func apply(_ action: CoachAction, userId: String) async throws {
        try await execute(action, userId: userId, recordForUndo: true)
        analytics.track(.coachActionApplied(action: action.id))
    }

    func undo(userId: String) async throws {
        guard let last = undoStack.popLast() else { return }
        try await execute(last.action.inverse, userId: userId, recordForUndo: false)
        analytics.track(.coachActionUndone(action: last.action.id))
    }

    // MARK: Execution

    private func execute(_ action: CoachAction, userId: String, recordForUndo: Bool) async throws {
        switch action {
        case .swapExercise(let from, let to, _):
            // Persist as a substitute preference — future program generation
            // + live sessions will pick up the new exercise.
            let pref = ExercisePreference(
                id: "\(userId):\(from.lowercased())",
                userId: userId,
                exerciseName: from.lowercased(),
                displayName: from.capitalized,
                status: .substitute,
                muscleGroups: [],
                substitutePreference: to.lowercased(),
                notes: "Set by coach",
                updatedAt: Date()
            )
            try await preferenceService.setPreference(pref)

        case .insertDeload(_):
            let states = await progressionStore.fetchAll(userId: userId)
            let deloaded = DeloadPlanner.shared.planDeload(for: states)
            for s in deloaded {
                await progressionStore.save(s)
            }

        case .adjustRepRange(let exerciseKey, let newMin, let newMax):
            if exerciseKey.hasPrefix("__revert_deload_") { return }
            if var state = await progressionStore.fetch(userId: userId, exerciseKey: exerciseKey) {
                state.targetRepMin = newMin
                state.targetRepMax = newMax
                state.updatedAt = Date()
                await progressionStore.save(state)
            }

        case .acknowledgePlateau:
            // Pure log entry.
            break
        }

        if recordForUndo {
            let entry = AppliedCoachAction(id: UUID(), action: action, appliedAt: Date())
            undoStack.append(entry)
            if undoStack.count > maxUndo {
                undoStack.removeFirst(undoStack.count - maxUndo)
            }
            history.insert(entry, at: 0)
            if history.count > 20 {
                history = Array(history.prefix(20))
            }
        }
    }

    func isWithinUndoWindow(_ entry: AppliedCoachAction) -> Bool {
        Date().timeIntervalSince(entry.appliedAt) < undoWindow
    }
}
