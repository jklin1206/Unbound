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

    var body: some View {
        Menu {
            Button {
                onIntent(.toggleWarmup)
            } label: {
                Label(isWarmup ? "Unmark warmup" : "Mark as warmup",
                      systemImage: "flame")
            }
            Button { onIntent(.addSet) } label: {
                Label("Add set", systemImage: "plus.circle")
            }
            Button { onIntent(.removeSet) } label: {
                Label("Remove last set", systemImage: "minus.circle")
            }
            Button { onIntent(.editNotes) } label: {
                Label("Notes", systemImage: "note.text")
            }
            Button { onIntent(.swapExercise) } label: {
                Label("Swap exercise", systemImage: "arrow.triangle.2.circlepath")
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
