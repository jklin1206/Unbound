import SwiftUI

enum OverflowIntent {
    case toggleWarmup
    case editNotes
    case swapExercise
    case addSet
    case removeSet
    case skipExercise
}

struct ExerciseOverflowMenu: View {
    let isWarmup: Bool
    let onIntent: (OverflowIntent) -> Void

    // The weight unit moved off the column header (it used to be a tappable
    // "WEIGHT LB ⇆" toggle) and lives here as an explicit menu action.
    @AppStorage(WeightPlatePolicy.unitDefaultsKey)
    private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    private var unit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    var body: some View {
        Menu {
            Button {
                onIntent(.toggleWarmup)
            } label: {
                Label(isWarmup ? "Unmark warmup" : "Mark as warmup",
                      systemImage: "flame")
            }
            Button { onIntent(.removeSet) } label: {
                Label("Remove last set", systemImage: "minus.circle")
            }
            Button { onIntent(.editNotes) } label: {
                Label("Notes", systemImage: "note.text")
            }
            Button {
                UnboundHaptics.tick()
                weightUnitRaw = (unit == .kilograms ? TrainingWeightUnit.pounds : .kilograms).rawValue
            } label: {
                Label(
                    unit == .kilograms ? "Switch to pounds" : "Switch to kilograms",
                    systemImage: "scalemass"
                )
            }
            Divider()
            Button(role: .destructive) { onIntent(.skipExercise) } label: {
                Label("Skip exercise", systemImage: "forward.end")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 44, height: 44)
        }
    }
}
