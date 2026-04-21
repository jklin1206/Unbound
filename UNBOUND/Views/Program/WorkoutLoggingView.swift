import SwiftUI

struct WorkoutLoggingView: View {
    @StateObject private var viewModel: WorkoutLoggingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var elapsedSeconds = 0
    @State private var saveSuccess = false
    @State private var swapSheetIndex: Int?
    @State private var swapAlternatives: [CatalogExercise] = []
    @State private var swapPreferences: [ExercisePreference] = []
    @State private var showingCustomBuilder = false
    private let servicesRef: ServiceContainer

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(workout: Workout, programId: String, dayNumber: Int, services: ServiceContainer) {
        self.servicesRef = services
        _viewModel = StateObject(wrappedValue: WorkoutLoggingViewModel(
            workout: workout,
            programId: programId,
            dayNumber: dayNumber,
            services: services
        ))
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.theme.surface)

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(viewModel.exerciseEntries.indices), id: \.self) { index in
                            exerciseCard(index: index)
                        }

                        sessionFooter
                    }
                    .padding(16)
                    .padding(.bottom, 100)
                }
            }

            // Bottom CTA
            VStack {
                Spacer()
                bottomBar
            }
        }
        .task {
            await viewModel.loadWorkingWeights()
            if let userId = servicesRef.auth.currentUserId {
                swapPreferences = (try? await servicesRef.exercisePreference.fetchPreferences(userId: userId)) ?? []
            }
        }
        .onReceive(timer) { _ in
            elapsedSeconds += 1
        }
        .sheet(item: Binding(
            get: { swapSheetIndex.map(SwapContext.init(index:)) },
            set: { swapSheetIndex = $0?.index }
        )) { ctx in
            ExerciseSwapSheet(
                currentExerciseName: viewModel.exerciseEntries[ctx.index].exercise.name,
                alternatives: swapAlternatives,
                onSelect: { alt in
                    viewModel.swapExercise(at: ctx.index, to: alt)
                    HapticManager.notification(.success)
                },
                onCreateCustom: {
                    showingCustomBuilder = true
                }
            )
        }
        .sheet(isPresented: $showingCustomBuilder) {
            CustomExerciseBuilderView()
                .environmentObject(servicesRef)
        }
    }

    private struct SwapContext: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private func presentSwap(at index: Int) {
        swapAlternatives = viewModel.alternatives(for: index, preferences: swapPreferences)
        swapSheetIndex = index
        UnboundHaptics.medium()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.workout.name)
                    .font(.subheadline(18))
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption(12))
                    .foregroundColor(.theme.textMuted)
            }

            Spacer()

            // Elapsed timer
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption(13))
                    .foregroundColor(.theme.textMuted)
                Text(formattedElapsed)
                    .font(.stat(16))
                    .foregroundColor(.theme.primary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.theme.surfaceLight)
            .clipShape(Capsule())
        }
    }

    private var formattedElapsed: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Exercise Card

    private func exerciseCard(index: Int) -> some View {
        let entry = viewModel.exerciseEntries[index]
        let normalized = entry.exercise.name.lowercased().replacingOccurrences(of: " ", with: "_")
        let suggestion = viewModel.progressionSuggestions[normalized]

        return VStack(alignment: .leading, spacing: 12) {
            // Exercise header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(entry.exercise.name)
                            .font(.bodyMedium(16))
                            .foregroundColor(entry.skipped ? .theme.textMuted : .theme.textPrimary)
                            .strikethrough(entry.skipped)
                        if entry.swapped {
                            Text("SWAPPED")
                                .font(.caption(10))
                                .fontWeight(.bold)
                                .foregroundColor(.theme.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.theme.primary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(entry.exercise.sets) × \(entry.exercise.reps)")
                        .font(.caption(13))
                        .foregroundColor(.theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    // Skip button
                    Button {
                        viewModel.toggleSkip(at: index)
                        HapticManager.selection()
                    } label: {
                        Text(entry.skipped ? "Unskip" : "Skip")
                            .font(.caption(12))
                            .foregroundColor(entry.skipped ? .theme.primary : .theme.textMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.theme.surfaceLight)
                            .clipShape(Capsule())
                    }
                }
            }

            // Last performance + progression suggestion
            if !entry.lastWeight.isEmpty || suggestion != nil {
                HStack(spacing: 8) {
                    if !entry.lastWeight.isEmpty {
                        Text("Last: \(entry.lastWeight)kg × \(entry.lastReps)")
                            .font(.caption(12))
                            .foregroundColor(.theme.textMuted)
                    }

                    if let suggestion {
                        Text(suggestion.description)
                            .font(.caption(12))
                            .fontWeight(.semibold)
                            .foregroundColor(.theme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.theme.success.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            if !entry.skipped {
                Divider().background(Color.theme.surfaceLight)

                // Set rows
                ForEach(Array(entry.sets.indices), id: \.self) { setIndex in
                    SetLogRow(
                        setNumber: setIndex + 1,
                        weightKg: Binding(
                            get: { viewModel.exerciseEntries[index].sets[setIndex].weightKg },
                            set: { viewModel.exerciseEntries[index].sets[setIndex].weightKg = $0 }
                        ),
                        reps: Binding(
                            get: { viewModel.exerciseEntries[index].sets[setIndex].reps },
                            set: { viewModel.exerciseEntries[index].sets[setIndex].reps = $0 }
                        ),
                        rpe: Binding(
                            get: { viewModel.exerciseEntries[index].sets[setIndex].rpe },
                            set: { viewModel.exerciseEntries[index].sets[setIndex].rpe = $0 }
                        ),
                        isWarmup: Binding(
                            get: { viewModel.exerciseEntries[index].sets[setIndex].isWarmup },
                            set: { viewModel.exerciseEntries[index].sets[setIndex].isWarmup = $0 }
                        ),
                        onDelete: entry.sets.count > 1 ? {
                            viewModel.removeSet(exerciseIndex: index, setIndex: setIndex)
                            HapticManager.impact(.light)
                        } : nil
                    )
                }

                // Add Set button
                Button {
                    viewModel.addSet(to: index)
                    HapticManager.impact(.light)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.caption(13))
                        Text("Add Set")
                            .font(.caption(13))
                    }
                    .foregroundColor(.theme.textSecondary)
                    .padding(.top, 4)
                }

                // Per-exercise notes
                TextField("Exercise notes…", text: Binding(
                    get: { viewModel.exerciseEntries[index].notes },
                    set: { viewModel.exerciseEntries[index].notes = $0 }
                ), axis: .vertical)
                    .font(.bodyText(13))
                    .foregroundColor(.theme.textSecondary)
                    .padding(10)
                    .background(Color.theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(entry.skipped ? 0.6 : 1)
        .onLongPressGesture(minimumDuration: 0.45) {
            presentSwap(at: index)
        }
    }

    // MARK: - Session Footer

    private var sessionFooter: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session Notes")
                .font(.subheadline(15))
                .foregroundColor(.theme.textPrimary)

            TextField("How did it go?", text: $viewModel.overallNotes, axis: .vertical)
                .font(.bodyText(14))
                .foregroundColor(.theme.textSecondary)
                .padding(12)
                .background(Color.theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .lineLimit(3...6)

            HStack {
                Text("Session RPE")
                    .font(.bodyMedium(14))
                    .foregroundColor(.theme.textSecondary)

                Spacer()

                Menu {
                    ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                        Button("RPE \(value)") { viewModel.overallRPE = value }
                    }
                    Button("Clear") { viewModel.overallRPE = nil }
                } label: {
                    Text(viewModel.overallRPE.map { "RPE \($0)" } ?? "Set RPE")
                        .font(.caption(13))
                        .foregroundColor(viewModel.overallRPE != nil ? .theme.primary : .theme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.theme.surfaceLight)
                        .clipShape(Capsule())
                }
            }

            // Session summary
            HStack(spacing: 0) {
                summaryCell(value: formattedElapsed, label: "Duration")
                Divider().frame(height: 36).background(Color.theme.surfaceLight)
                summaryCell(value: "\(viewModel.totalSets)", label: "Work Sets")
                Divider().frame(height: 36).background(Color.theme.surfaceLight)
                summaryCell(
                    value: "\(viewModel.exerciseEntries.filter { !$0.skipped }.count)",
                    label: "Exercises"
                )
            }
            .padding(.vertical, 12)
            .background(Color.theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.stat(18))
                .foregroundColor(.theme.textPrimary)
            Text(label)
                .font(.caption(11))
                .foregroundColor(.theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.theme.surfaceLight)
            GradientButton(
                title: "Complete Workout",
                action: {
                    Task {
                        await viewModel.saveLog()
                        if !viewModel.isSaving {
                            dismiss()
                        }
                    }
                },
                isLoading: viewModel.isSaving
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.theme.background)
    }
}
