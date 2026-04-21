import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var services: ServiceContainer
    var programId: String = ""
    var dayNumber: Int = 0
    @State private var showLogging = false

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header stats
                    workoutHeader

                    // Warmup
                    if !workout.warmup.isEmpty {
                        exerciseSection(title: "Warmup", icon: "figure.run", exercises: workout.warmup)
                    }

                    // Main
                    exerciseSection(title: "Main Workout", icon: "dumbbell.fill", exercises: workout.mainExercises)

                    // Cooldown
                    if !workout.cooldown.isEmpty {
                        exerciseSection(title: "Cooldown", icon: "figure.cooldown", exercises: workout.cooldown)
                    }

                    GradientButton(title: "Log Workout", action: {
                        showLogging = true
                    })
                    .padding(.top, 8)
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showLogging) {
            NavigationStack {
                WorkoutLoggingView(
                    workout: workout,
                    programId: programId,
                    dayNumber: dayNumber,
                    services: services
                )
            }
        }
    }

    private var workoutHeader: some View {
        HStack(spacing: 0) {
            statCell(value: "\(workout.mainExercises.count)", label: "Exercises")
            Divider().frame(height: 40).background(Color.theme.surfaceLight)
            statCell(value: "\(workout.estimatedMinutes)", label: "Minutes")
            Divider().frame(height: 40).background(Color.theme.surfaceLight)
            statCell(
                value: workout.targetMuscleGroups.prefix(2).map(\.displayName).joined(separator: "/"),
                label: "Focus"
            )
        }
        .padding(.vertical, 16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.bodyMedium(16))
                .foregroundColor(.theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption(12))
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseSection(title: String, icon: String, exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline(16))
                .foregroundColor(.theme.textPrimary)

            VStack(spacing: 8) {
                ForEach(exercises) { exercise in
                    ExerciseRow(exercise: exercise)
                }
            }
        }
    }
}

// MARK: - Exercise Row

private struct ExerciseRow: View {
    let exercise: Exercise
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.bodyMedium(15))
                            .foregroundColor(.theme.textPrimary)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            Text("\(exercise.sets) × \(exercise.reps)")
                                .font(.caption(13))
                                .foregroundColor(.theme.textSecondary)

                            if exercise.restSeconds > 0 {
                                Text("Rest \(exercise.restSeconds)s")
                                    .font(.caption(13))
                                    .foregroundColor(.theme.textMuted)
                            }
                        }
                    }

                    Spacer()

                    // Muscle group tags
                    HStack(spacing: 4) {
                        ForEach(exercise.muscleGroups.prefix(2), id: \.self) { group in
                            Text(group.displayName)
                                .font(.caption(11))
                                .foregroundColor(.theme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.theme.primary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().background(Color.theme.surfaceLight)

            if let rpe = exercise.rpe {
                HStack(spacing: 6) {
                    Text("RPE:")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                    Text("\(rpe)/10")
                        .font(.bodyMedium(13))
                        .foregroundColor(.theme.textSecondary)
                }
            }

            if let notes = exercise.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Form Cues")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                    Text(notes)
                        .font(.bodyText(13))
                        .foregroundColor(.theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let sub = exercise.substitution, !sub.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Substitution")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                    Text(sub)
                        .font(.bodyText(13))
                        .foregroundColor(.theme.secondary)
                }
            }

            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                Text("Full Details →")
                    .font(.caption(13))
                    .foregroundColor(.theme.primary)
            }
        }
    }
}
