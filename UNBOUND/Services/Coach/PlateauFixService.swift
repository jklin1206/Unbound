import Foundation

// MARK: - PlateauFixService
//
// Deterministic diagnosis for a stalled lift. Returns a structured result:
// diagnosis sentence + 3-week prescription. No back-and-forth. Called
// from PlateauFixSheet — result shown as a card.

@MainActor
final class PlateauFixService {
    static let shared = PlateauFixService()
    private let database = DatabaseService.shared
    private init() {}

    struct PlateauFix {
        let exerciseName: String
        let diagnosis: String          // 1-2 sentences — why it's stalled
        let weeks: [FixWeek]
    }

    struct FixWeek {
        let label: String              // "WEEK 1", "WEEK 2", "WEEK 3"
        let focus: String              // "Volume drop", "Technique reset", etc.
        let instruction: String        // Concrete single-sentence directive
    }

    func generate(for plateau: PlateauedExercise, userId: String) async throws -> PlateauFix {
        let states: [ProgressionState] = (try? await database.query(
            collection: "progression_states",
            field: "userId",
            isEqualTo: userId,
            orderBy: "updatedAt",
            descending: true,
            limit: 20
        )) ?? []

        let matchedState = states.first {
            $0.exerciseKey.contains(plateau.exerciseKey.lowercased())
        }

        return PlateauFix(
            exerciseName: plateau.displayName,
            diagnosis: diagnosis(for: plateau, state: matchedState),
            weeks: weeks(for: plateau, state: matchedState)
        )
    }

    // MARK: - Deterministic rules

    private func diagnosis(for plateau: PlateauedExercise, state: ProgressionState?) -> String {
        if let state, state.blockType == .deload {
            return "\(plateau.displayName) is already in a deload response. Keep the reset controlled before pushing load again."
        }
        if plateau.stalledSessions >= 4 {
            return "\(plateau.displayName) has stalled across multiple exposures, so the next move is a short volume reset and cleaner top-set target."
        }
        return "\(plateau.displayName) is showing an early plateau signal. Hold intensity steady and rebuild high-quality reps before adding load."
    }

    private func weeks(for plateau: PlateauedExercise, state: ProgressionState?) -> [FixWeek] {
        let weight = state.map { formatWeight($0.currentWorkingWeightKg) } ?? "current load"
        let repRange = state.map { "\($0.targetRepMin)-\($0.targetRepMax)" } ?? "target"
        return [
            FixWeek(
                label: "WEEK 1",
                focus: "Reset",
                instruction: "Drop to 90% of \(weight), keep \(repRange) reps clean, and stop at RPE 7."
            ),
            FixWeek(
                label: "WEEK 2",
                focus: "Rebuild",
                instruction: "Return to \(weight) only if all work sets hit the rep floor without form drift."
            ),
            FixWeek(
                label: "WEEK 3",
                focus: "Advance",
                instruction: "Add the smallest available load bump after hitting the top of the range at RPE 8 or lower."
            )
        ]
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))kg"
            : String(format: "%.1fkg", weight)
    }
}
