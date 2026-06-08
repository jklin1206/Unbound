import Foundation

/// Builds the empty draft that backs "Quick Log" — an on-the-fly free workout.
/// The user adds exercises/sets live via ActiveWorkoutSession.appendCustomExercise.
enum QuickLogDraftFactory {
    static func empty(userId: String) -> TrainingSessionDraft {
        TrainingSessionDraft(
            userId: userId,
            source: .custom,
            title: "Quick Log",
            estimatedMinutes: 0,
            blocks: []
        )
    }
}
