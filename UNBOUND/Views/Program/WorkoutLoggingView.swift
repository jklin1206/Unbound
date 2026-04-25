import SwiftUI

// MARK: - WorkoutLoggingView
//
// The in-gym surface. Big enough to log sets with gloves, tight enough
// to read fast between sets. Built in the UNBOUND palette (charcoal on
// black, violet accent, mono digits). Preserves the original logic —
// sets, RPE, skips, swaps, progression suggestions, session notes, save.

struct WorkoutLoggingView: View {
    @StateObject private var viewModel: WorkoutLoggingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var elapsedSeconds = 0
    @State private var saveSuccess = false
    @State private var swapSheetIndex: Int?
    @State private var swapAlternatives: [CatalogExercise] = []
    @State private var swapPreferences: [ExercisePreference] = []
    @State private var showingCustomBuilder = false
    @State private var shortModeApplied = false
    @AppStorage("unbound.shortSessionDate") private var shortSessionDate: Double = 0
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
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if shortModeApplied {
                    shortModeBanner
                }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(Array(viewModel.exerciseEntries.indices), id: \.self) { index in
                            exerciseCard(index: index)
                        }
                        sessionFooter
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }

            VStack {
                Spacer()
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadWorkingWeights()
            if let userId = servicesRef.auth.currentUserId {
                swapPreferences = (try? await servicesRef.exercisePreference.fetchPreferences(userId: userId)) ?? []
            }
            applyShortModeIfActive()
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
                    UnboundHaptics.success()
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

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.workout.name.uppercased())
                    .font(Font.unbound.titleS)
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                Text(Date().formatted(date: .abbreviated, time: .omitted).uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer()

            timerBadge
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            Color.unbound.bg
                .overlay(
                    Rectangle().fill(Color.unbound.borderSubtle).frame(height: 0.5),
                    alignment: .bottom
                )
        )
    }

    private var timerBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
            Text(formattedElapsed)
                .font(Font.unbound.monoM.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.unbound.surface))
        .overlay(
            Capsule().strokeBorder(Color.unbound.accent.opacity(0.40), lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(0.25), radius: 5)
    }

    // MARK: - Short mode

    /// Auto-skip exercises beyond the first 3 compounds when the user
    /// activated short mode today. Idempotent via `shortModeApplied`.
    private func applyShortModeIfActive() {
        guard !shortModeApplied else { return }
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        guard shortSessionDate > 0,
              abs(shortSessionDate - today) < 60 else { return }

        for index in viewModel.exerciseEntries.indices where index >= 3 {
            if !viewModel.exerciseEntries[index].skipped {
                viewModel.toggleSkip(at: index)
            }
        }
        shortModeApplied = true
    }

    private var shortModeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.coachCyan)
            Text("SHORT MODE · COMPOUNDS ONLY")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.coachCyan)
            Spacer()
            Button {
                UnboundHaptics.soft()
                disableShortMode()
            } label: {
                Text("UNDO")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle().fill(Color.unbound.coachCyan.opacity(0.12))
        )
        .overlay(
            Rectangle().fill(Color.unbound.coachCyan.opacity(0.3)).frame(height: 0.5),
            alignment: .bottom
        )
    }

    private func disableShortMode() {
        for index in viewModel.exerciseEntries.indices where index >= 3 {
            if viewModel.exerciseEntries[index].skipped {
                viewModel.toggleSkip(at: index)
            }
        }
        shortModeApplied = false
        shortSessionDate = 0
    }

    private var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Exercise card

    private func exerciseCard(index: Int) -> some View {
        let entry = viewModel.exerciseEntries[index]
        let normalized = entry.exercise.name.lowercased().replacingOccurrences(of: " ", with: "_")
        let suggestion = viewModel.progressionSuggestions[normalized]

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(entry.exercise.name.uppercased())
                            .font(Font.unbound.bodyMStrong)
                            .tracking(0.6)
                            .foregroundStyle(
                                entry.skipped ? Color.unbound.textTertiary : Color.unbound.textPrimary
                            )
                            .strikethrough(entry.skipped)
                        if entry.swapped {
                            Text("SWAPPED")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Color.unbound.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.unbound.accent.opacity(0.18)))
                        }
                    }

                    Text("\(entry.exercise.sets) × \(entry.exercise.reps)".uppercased())
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }

                Spacer()

                // Skip toggle
                Button {
                    viewModel.toggleSkip(at: index)
                    UnboundHaptics.soft()
                } label: {
                    Text(entry.skipped ? "UNSKIP" : "SKIP")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(
                            entry.skipped ? Color.unbound.accent : Color.unbound.textTertiary
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.unbound.bg))
                        .overlay(
                            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            // Progression + last-session callouts
            if !entry.lastWeight.isEmpty || suggestion != nil {
                HStack(spacing: 8) {
                    if !entry.lastWeight.isEmpty {
                        calloutChip(
                            text: "LAST · \(entry.lastWeight)KG × \(entry.lastReps)",
                            color: Color.unbound.textSecondary,
                            fill: Color.unbound.bg
                        )
                    }
                    if let suggestion {
                        calloutChip(
                            text: suggestion.description.uppercased(),
                            color: Color.unbound.success,
                            fill: Color.unbound.success.opacity(0.12)
                        )
                    }
                    Spacer(minLength: 0)
                }
            }

            if !entry.skipped {
                // Column headers for the set table
                HStack(spacing: 10) {
                    columnHeader("SET", width: 26)
                    columnHeader("WEIGHT", width: 60)
                    columnHeader("REPS", width: 46)
                    columnHeader("RPE", width: nil)
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)

                Rectangle()
                    .fill(Color.unbound.borderSubtle)
                    .frame(height: 0.5)

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
                        } : nil
                    )
                }

                Button {
                    viewModel.addSet(to: index)
                    UnboundHaptics.soft()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("ADD SET")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.4)
                    }
                    .foregroundStyle(Color.unbound.accent)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                // Per-exercise notes
                TextField("Notes…", text: Binding(
                    get: { viewModel.exerciseEntries[index].notes },
                    set: { viewModel.exerciseEntries[index].notes = $0 }
                ), axis: .vertical)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .tint(Color.unbound.accent)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.unbound.bg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .opacity(entry.skipped ? 0.55 : 1)
        .onLongPressGesture(minimumDuration: 0.45) {
            presentSwap(at: index)
        }
    }

    private func columnHeader(_ label: String, width: CGFloat?) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Color.unbound.textTertiary)
            .frame(width: width, alignment: width == nil ? .leading : .center)
    }

    private func calloutChip(text: String, color: Color, fill: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.8))
    }

    // MARK: - Session footer

    private var sessionFooter: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SESSION")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)

            TextField("How did it go?", text: $viewModel.overallNotes, axis: .vertical)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textPrimary)
                .tint(Color.unbound.accent)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.bg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
                .lineLimit(3...6)

            HStack {
                Text("SESSION RPE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                Spacer()

                Menu {
                    ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                        Button("RPE \(value)") { viewModel.overallRPE = value }
                    }
                    Button("Clear") { viewModel.overallRPE = nil }
                } label: {
                    Text(viewModel.overallRPE.map { "RPE \($0)" } ?? "—")
                        .font(Font.unbound.monoS.weight(.semibold))
                        .foregroundStyle(
                            viewModel.overallRPE != nil
                                ? Color.unbound.accent
                                : Color.unbound.textTertiary
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.unbound.bg))
                        .overlay(
                            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }
            }

            // Session summary
            HStack(spacing: 0) {
                summaryCell(value: formattedElapsed, label: "DURATION")
                Divider().frame(height: 36).background(Color.unbound.borderSubtle)
                summaryCell(value: "\(viewModel.totalSets)", label: "WORK SETS")
                Divider().frame(height: 36).background(Color.unbound.borderSubtle)
                summaryCell(
                    value: "\(viewModel.exerciseEntries.filter { !$0.skipped }.count)",
                    label: "EXERCISES"
                )
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.bg)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    private func summaryCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Font.unbound.monoL)
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.unbound.borderSubtle)
                .frame(height: 0.5)

            Button {
                UnboundHaptics.medium()
                Task {
                    await viewModel.saveLog()
                    if !viewModel.isSaving {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isSaving {
                        ProgressView().tint(Color.unbound.textPrimary)
                    } else {
                        Text("COMPLETE SESSION")
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.6)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
                .shadow(color: Color.unbound.accent.opacity(0.45), radius: 14, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSaving)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color.unbound.bg)
    }
}
