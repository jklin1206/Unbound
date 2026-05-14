import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Muscle groups
                    muscleGroupsCard

                    // Programming
                    programmingCard

                    // Form cues
                    if let notes = exercise.notes, !notes.isEmpty {
                        formCuesCard(notes: notes)
                    }

                    // Substitution
                    if let sub = exercise.substitution, !sub.isEmpty {
                        substitutionCard(sub: sub)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var muscleGroupsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Muscles")
                .font(.subheadline(16))
                .foregroundColor(.theme.textPrimary)

            // Wrap-style layout
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(exercise.muscleGroups, id: \.self) { group in
                    Text(group.displayName)
                        .font(.bodyMedium(13))
                        .foregroundColor(.theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.theme.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var programmingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Programming")
                .font(.subheadline(16))
                .foregroundColor(.theme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                programmingCell(label: "Sets", value: "\(exercise.sets)")
                programmingCell(label: "Reps", value: exercise.reps)
                programmingCell(label: "Rest", value: "\(exercise.restSeconds)s")
                if let rpe = exercise.rpe {
                    programmingCell(label: "RPE", value: "\(rpe)/10")
                }
            }
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func programmingCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.stat(22))
                .foregroundColor(.theme.textPrimary)
            Text(label)
                .font(.caption(12))
                .foregroundColor(.theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.theme.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formCuesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Form Cues", systemImage: "checklist")
                .font(.subheadline(16))
                .foregroundColor(.theme.textPrimary)

            Text(notes)
                .font(.bodyText(15))
                .foregroundColor(.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func substitutionCard(sub: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Substitution", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline(16))
                .foregroundColor(.theme.textPrimary)

            Text(sub)
                .font(.bodyText(15))
                .foregroundColor(.theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            notes: "Keep chest up, brace core, drive through heels. Maintain neutral spine throughout the movement.",
            substitution: "Goblet Squat or Leg Press"
        ))
    }
}
