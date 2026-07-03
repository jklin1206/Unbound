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
    @State private var detent: PresentationDetent = .medium

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
            // Typing needs room: the keyboard eats the medium detent, so the
            // sheet grows to full height the moment search gains focus.
            onSearchFocused: { detent = .large },
            onDismiss: { dismiss() }
        )
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }
}
