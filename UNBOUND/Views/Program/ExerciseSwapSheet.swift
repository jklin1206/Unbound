import SwiftUI

/// Shell around `ProgramExerciseLibraryView` — owns presentation chrome
/// (close button, Done bar) and dismissal, so the library view itself stays a
/// pure list with no opinion about how it was presented.
struct ExerciseSwapSheet: View {
    var mode: ProgramExerciseLibraryView.Mode = .swap
    let currentExerciseName: String
    let alternatives: [CatalogExercise]
    let onSelect: (CatalogExercise) -> Void
    var onDeselect: (CatalogExercise) -> Void = { _ in }
    var recentExerciseNames: Set<String> = []
    var preferenceStatusesByKey: [String: ExercisePreferenceStatus] = [:]
    var availableEquipment: [Equipment]? = nil
    var onCreateCustom: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var addedKeys: Set<String> = []

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                closeBar
                ProgramExerciseLibraryView(
                    mode: mode,
                    currentExerciseName: currentExerciseName,
                    alternatives: alternatives,
                    onRowTap: handleRowTap,
                    recentExerciseNames: recentExerciseNames,
                    preferenceStatusesByKey: preferenceStatusesByKey,
                    availableEquipment: availableEquipment,
                    // create-custom still leaves the picker — close this cover
                    // first, then let the call site's own routing run.
                    onCreateCustom: onCreateCustom.map { custom in
                        { dismiss(); custom() }
                    },
                    addedKeys: addedKeys
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if mode.showsDoneBar {
                doneBar
            }
        }
        #if DEBUG
        // Dev harness: `--unbound-demo-multiadd-seed` drives the real row-tap
        // path — two adds plus one add-then-undo — so the multi-add states are
        // reviewable on-sim without tap tooling. Targets exercises that rank
        // near the top of the visible list; `alternatives` itself is unranked.
        .onAppear {
            guard mode == .addMulti,
                  ProcessInfo.processInfo.arguments.contains("--unbound-demo-multiadd-seed")
            else { return }
            let picks = ["ab wheel", "assisted squat", "bicycle crunch"]
                .compactMap { name in alternatives.first { $0.name == name } }
            for exercise in picks { handleRowTap(exercise) }
            if let undone = picks.last { handleRowTap(undone) }
        }
        #endif
    }

    private var closeBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var doneBar: some View {
        Button {
            dismiss()
        } label: {
            Text(addedKeys.isEmpty ? "Done" : "Done · \(addedKeys.count) added")
                .font(Font.unbound.bodyMStrong)
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
                .shadow(color: Color.unbound.accent.opacity(0.35), radius: 14, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Color.unbound.bg.opacity(0.94))
    }

    private func handleRowTap(_ exercise: CatalogExercise) {
        if mode.dismissesOnSelect {
            UnboundHaptics.medium()
            onSelect(exercise)
            dismiss()
            return
        }

        // .addMulti — tap toggles the row: first tap adds, second tap undoes.
        let key = ProgramExerciseLibraryView.canonicalKey(for: exercise)
        if addedKeys.contains(key) {
            addedKeys.remove(key)
            UnboundHaptics.soft()
            onDeselect(exercise)
        } else {
            addedKeys.insert(key)
            UnboundHaptics.medium()
            onSelect(exercise)
        }
    }
}
