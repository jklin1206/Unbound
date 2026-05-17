import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            ScrollView {
                ExerciseDetailSections(
                    muscleGroups: exercise.muscleGroups,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    restSeconds: exercise.restSeconds,
                    formCues: exercise.notes,
                    substitution: exercise.substitution
                )
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: Exercise(
            id: "1",
            name: "Barbell Back Squat",
            muscleGroups: [.legs, .glutes, .core],
            sets: 4,
            reps: "6-8",
            restSeconds: 120,
            rpe: 8,
            notes: "Keep chest up, brace core, drive through heels.",
            substitution: "Goblet Squat or Leg Press"
        ))
    }
}
