import SwiftUI

struct ExerciseSwapSheet: View {
    enum Mode {
        case add
        case swap
    }

    var mode: Mode = .swap
    let currentExerciseName: String
    let alternatives: [CatalogExercise]
    let onSelect: (CatalogExercise) -> Void
    var recentExerciseNames: Set<String> = []
    var preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:]
    var availableEquipment: [Equipment]? = nil
    var onCreateCustom: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ProgramExerciseLibraryView(
            mode: mode == .add ? .add : .swap,
            currentExerciseName: currentExerciseName,
            alternatives: alternatives,
            onSelect: onSelect,
            recentExerciseNames: recentExerciseNames,
            preferenceStatusesByKey: preferenceStatusesByKey,
            availableEquipment: availableEquipment,
            onCreateCustom: onCreateCustom,
            onDismiss: { dismiss() }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }
}
