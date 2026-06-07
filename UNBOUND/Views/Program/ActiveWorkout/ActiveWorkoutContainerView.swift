import SwiftUI

// MARK: - ActiveWorkoutContainerView
//
// Session orchestrator for the new grid-based logging surface.
// Owns the ActiveWorkoutSession, autosaves drafts, hosts WorkoutLogGridView
// + timer chrome, and on COMPLETE assembles + saves unified
// PerformanceLog data before showing the post-workout reward sequence.

struct ActiveWorkoutContainerView: View {
    @StateObject private var session: ActiveWorkoutSession
    @State private var priorEntries: [ExerciseLogEntry] = []
    @State private var workingWeightKg: Double? = nil
    @State private var saving = false
    @State private var showCompleteConfirm = false
    @State private var saveError = false
    @State private var showExitConfirm = false

    // Swap sheet state
    @State private var swapExerciseIndex: Int? = nil
    @State private var swapAlternatives: [CatalogExercise] = []
    @State private var showingCustomBuilder = false

    // Notes editing state
    @State private var notesEditingIndex: Int? = nil
    @State private var notesEditingText: String = ""
    @State private var showNotesSheet = false

    // Reward state
    @State private var rewardSequence: WorkoutRewardSequenceSummary? = nil
    @State private var isFinishingRewardSequence = false

    // Grid cell editor state
    @State private var editing: EditTarget? = nil

    // RPE picker state
    @State private var rpeTarget: RPETarget?
    private struct RPETarget: Identifiable { let id = UUID(); let ei: Int; let si: Int }

    // Rest timer
    @ObservedObject private var restTimer = RestTimerModel.shared
    @State private var workoutElapsedSeconds = 0
    private let restClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) private var microloadingEnabled = false

    private let services: ServiceContainer
    private let draftStore: WorkoutDraftStore
    private let onFinished: (() -> Void)?

    // MARK: - Private types

    struct EditTarget: Identifiable {
        let id = UUID()
        let ei: Int
        let si: Int
        let isWeight: Bool
    }

    private struct SwapContext: Identifiable {
        let index: Int
        var id: Int { index }
    }

    // MARK: - Init

    init(
        workout: Workout,
        programId: String,
        dayNumber: Int,
        services: ServiceContainer,
        resuming: ActiveWorkoutSession? = nil,
        onFinished: (() -> Void)? = nil
    ) {
        self.services = services
        self.draftStore = WorkoutDraftStore()
        self.onFinished = onFinished
        _session = StateObject(
            wrappedValue: resuming
                ?? ActiveWorkoutSession(workout: workout, programId: programId, dayNumber: dayNumber)
        )
    }

    init(
        draft: TrainingSessionDraft,
        services: ServiceContainer,
        onFinished: (() -> Void)? = nil
    ) {
        self.services = services
        self.draftStore = WorkoutDraftStore()
        self.onFinished = onFinished
        _session = StateObject(wrappedValue: ActiveWorkoutSession(trainingDraft: draft))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                workoutTopBar

                WorkoutLogGridView(
                    session: session,
                    rankTrialDefinition: rankTrialDefinition,
                    onIntent: { ei, intent in handleIntent(ei, intent) },
                    onEditWeight: { ei, si in editing = EditTarget(ei: ei, si: si, isWeight: true) },
                    onEditReps:   { ei, si in editing = EditTarget(ei: ei, si: si, isWeight: false) },
                    onPickRPE: { ei, si in rpeTarget = RPETarget(ei: ei, si: si) },
                    onConfirmAsPlanned: { ei, si in
                        let shouldUseDeckFlow = isDeckTrial
                        session.confirmAsPlanned(exerciseIndex: ei, setIndex: si)
                        try? draftStore.save(session)
                        if shouldUseDeckFlow && !session.hasUnloggedWorkingSets {
                            restTimer.stop()
                            Task { await complete() }
                        } else {
                            transition(ei: ei)
                        }
                    },
                    onToggleQualityFlag: { ei, si, flag in
                        session.toggleQualityFlag(flag, exerciseIndex: ei, setIndex: si)
                        try? draftStore.save(session)
                    },
                    onAddSet: { ei in
                        session.addSet(toExerciseIndex: ei)
                        try? draftStore.save(session)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isDeckTrial {
                deckRestFooter
            } else {
                completionFooter
            }
        }
        .onReceive(restClock) { now in
            restTimer.tick(now: now)
            workoutElapsedSeconds = Self.elapsedSeconds(since: session.startedAt, now: now)
        }
        .task {
            workoutElapsedSeconds = Self.elapsedSeconds(since: session.startedAt)
            await loadContext()
        }
        .task {
            await RestNotifier.shared.requestAuthIfNeeded()
        }
        .task {
            // Broadcast squad presence while this workout is open so squadmates
            // see "live now". The server row auto-expires after 3h; complete()
            // clears it on finish.
            guard let uid = services.auth.currentUserId,
                  let squadId = services.squads.state(userId: uid).currentSquad?.id else { return }
            await services.squadPresence.markInWorkout(userId: uid, squadId: squadId)
        }
        .interactiveDismissDisabled(true)
        // Always-available escape hatch — the draft is autosaved on every
        // mutation, so leaving keeps the workout resumable. Without this the
        // user is trapped whenever saveLog fails.
        .confirmationDialog(
            "Leave this workout?",
            isPresented: $showExitConfirm,
            titleVisibility: .visible
        ) {
            Button("Save & finish") {
                showExitConfirm = false
                Task { await complete() }
            }
            Button("Leave (keeps progress)", role: .destructive) { dismiss() }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("Your logged sets are saved as a draft you can resume.")
        }
        // saveLog failed — never trap the user; let them retry or leave.
        .alert("Couldn't save workout", isPresented: $saveError) {
            Button("Retry") { Task { await complete() } }
            Button("Leave (keeps draft)", role: .cancel) { dismiss() }
        } message: {
            Text("Check your connection. Your progress is saved locally and will be here when you come back.")
        }
        // Complete confirmation dialog
        .confirmationDialog(
            "Finish with sets remaining?",
            isPresented: $showCompleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish workout", role: .destructive) {
                showCompleteConfirm = false
                Task { await complete() }
            }
            Button("Keep training", role: .cancel) {}
        }
        // Grid cell editor sheet
        .sheet(item: $editing) { t in
            EditorSheet(
                session: session,
                ei: t.ei,
                si: t.si,
                isWeight: t.isWeight,
                onCommitted: {
                    try? draftStore.save(session)
                }
            )
        }
        // RPE picker sheet
        .sheet(item: $rpeTarget) { t in
            RPEPickerSheet(
                current: (session.exercises.indices.contains(t.ei)
                          && session.exercises[t.ei].sets.indices.contains(t.si))
                    ? (session.exercises[t.ei].sets[t.si].rpe
                       ?? session.exercises[t.ei].sets[t.si].suggestedRPE)
                    : nil,
                onPick: { v in
                    session.setRPE(exerciseIndex: t.ei, setIndex: t.si, v)
                    try? draftStore.save(session)
                }
            )
            .presentationDetents([.height(420)])
        }
        // Swap sheet — uses the existing ExerciseSwapSheet with real init
        .sheet(item: Binding(
            get: { swapExerciseIndex.map(SwapContext.init(index:)) },
            set: { swapExerciseIndex = $0?.index }
        )) { ctx in
            ExerciseSwapSheet(
                currentExerciseName: session.exercises[ctx.index].name,
                alternatives: swapAlternatives,
                onSelect: { alt in
                    session.replaceExercise(at: ctx.index, with: alt)
                    swapExerciseIndex = nil
                    try? draftStore.save(session)
                },
                onCreateCustom: {
                    swapExerciseIndex = nil
                    showingCustomBuilder = true
                }
            )
        }
        // Custom exercise builder
        .sheet(isPresented: $showingCustomBuilder) {
            CustomExerciseBuilderView { exercise in
                session.appendCustomExercise(exercise)
                try? draftStore.save(session)
            }
                .environmentObject(services)
        }
        // Notes editing sheet — simple inline text entry
        .sheet(isPresented: $showNotesSheet) {
            NotesEditSheet(
                text: $notesEditingText,
                onSave: {
                    if let idx = notesEditingIndex {
                        session.setNotes(notesEditingText, forExerciseAt: idx)
                        try? draftStore.save(session)
                    }
                    showNotesSheet = false
                },
                onCancel: {
                    showNotesSheet = false
                }
            )
        }
        .fullScreenCover(item: $rewardSequence) { summary in
            WorkoutRewardSequenceView(summary: summary) {
                finishRewardSequence()
            }
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: - Computed helpers

    private var workoutTopBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                closeWorkoutButton
                Spacer(minLength: 0)
                workoutElapsedTime
                Spacer(minLength: 0)
                workoutModeBadge
            }

            workoutProgressRail
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var closeWorkoutButton: some View {
        Button {
            showExitConfirm = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.unbound.surface))
                .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close workout")
    }

    private var workoutElapsedTime: some View {
        VStack(spacing: 2) {
            Text("TOTAL TIME")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(Self.timeString(seconds: workoutElapsedSeconds))
                .font(Font.unbound.monoS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
        }
        .frame(minWidth: 92)
        .accessibilityLabel("Workout timer")
        .accessibilityValue(Self.timeString(seconds: workoutElapsedSeconds))
        .accessibilityIdentifier("workout.elapsedTime")
    }

    private var workoutModeBadge: some View {
        let tint = workoutHeaderTint
        let text = session.progressSummary.isComplete
            ? "FINISH"
            : (isRankTrial ? "TRIAL" : "LIVE")
        return Text(text)
            .font(Font.unbound.captionS.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.15)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .frame(width: 64)
            .accessibilityLabel(text == "FINISH" ? "Ready to finish" : text)
    }

    private var workoutProgressRail: some View {
        let progress = session.progressSummary
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(workoutProgressLabel(progress))
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.unbound.surface)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(workoutHeaderTint)
                        .frame(width: geo.size.width * workoutProgressFraction(progress), height: 3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress.loggedWorkingSets)
                }
            }
            .frame(height: 3)
        }
    }

    private var workoutHeaderTint: Color {
        isRankTrial ? Color.unbound.coachCyan : Color.unbound.accent
    }

    private func workoutProgressFraction(_ progress: ActiveWorkoutSession.ProgressSummary) -> CGFloat {
        guard progress.totalWorkingSets > 0 else { return 0 }
        return min(1, CGFloat(progress.loggedWorkingSets) / CGFloat(progress.totalWorkingSets))
    }

    private func workoutProgressLabel(_ progress: ActiveWorkoutSession.ProgressSummary) -> String {
        guard progress.totalWorkingSets > 0 else { return "SESSION IN PROGRESS" }
        if progress.isComplete { return "READY TO FINISH" }
        return "\(progress.loggedWorkingSets) OF \(progress.totalWorkingSets) WORK SETS"
    }

    private var totalLoggedWorkingSets: Int {
        session.exercises.filter { !$0.skipped }.reduce(0) {
            $0 + $1.sets.filter { !$0.isWarmup && $0.logged }.count
        }
    }

    private var rankTrialDefinition: OverallRankTrialDefinition? {
        guard session.source == .overallRankTrial else { return nil }
        return OverallRankTrialDefinitions.definition(id: session.programId)
    }

    private var isRankTrial: Bool {
        rankTrialDefinition != nil
    }

    private var isDeckTrial: Bool {
        rankTrialDefinition?.format == .fixedDeck
    }

    private var deckRestFooter: some View {
        RestTimerPill(
            model: restTimer,
            onAddThirty: { restTimer.addThirty() },
            onDismiss: { restTimer.dismiss() }
        )
        .padding(.bottom, 16)
        .allowsHitTesting(restTimer.isVisible)
    }

    private var completionFooter: some View {
        let progress = session.progressSummary
        return VStack(spacing: 10) {
            RestTimerPill(
                model: restTimer,
                onAddThirty: { restTimer.addThirty() },
                onDismiss: { restTimer.dismiss() }
            )

            HStack(spacing: 8) {
                Image(systemName: progress.isComplete ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(progress.isComplete ? Color.unbound.accent : Color.unbound.textTertiary)
                Text(progress.footerText.uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer()
            }
            .padding(.horizontal, 4)

            #if DEBUG
            Button(action: debugFillPlannedSets) {
                Label("Fill Planned Sets", systemImage: "wand.and.stars")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("workout.debug.fillPlannedSets")
            #endif

            Button(action: requestComplete) {
                HStack(spacing: 10) {
                    if saving {
                        ProgressView()
                            .tint(Color.unbound.bg)
                    }
                    Text(saving ? "SAVING SESSION" : completionButtonTitle(progress: progress))
                        .font(Font.unbound.bodyLStrong)
                        .tracking(2)
                }
                .foregroundStyle(Color.unbound.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 18)
                    .fill(saving ? Color.unbound.textSecondary : Color.unbound.accent))
                .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .disabled(saving)
            .accessibilityIdentifier("workout.complete")
            .accessibilityLabel(saving ? "Saving session" : (isRankTrial ? "Complete trial" : "Complete session"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(Color.unbound.bg.opacity(0.96))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.unbound.bg.opacity(0), Color.unbound.bg.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 42)
            .offset(y: -42)
            .allowsHitTesting(false)
        }
    }

    private func completionButtonTitle(progress: ActiveWorkoutSession.ProgressSummary) -> String {
        if isRankTrial {
            return progress.isComplete ? "FINISH TRIAL" : "COMPLETE TRIAL"
        }
        return progress.isComplete ? "FINISH SESSION" : "COMPLETE SESSION"
    }

    private static func elapsedSeconds(since startedAt: Date, now: Date = Date()) -> Int {
        max(0, Int(now.timeIntervalSince(startedAt).rounded(.down)))
    }

    private static func timeString(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3_600
        let minutes = (clamped % 3_600) / 60
        let seconds = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Rest timer

    private func startRest(ei: Int) {
        guard session.exercises.indices.contains(ei) else { return }
        let secs = session.exercises[ei].restSeconds
        let next = session.exercises[ei].name
        restTimer.onElapsed = { UnboundHaptics.success() }
        restTimer.start(seconds: secs, nextLabel: next)
    }

    /// Fired exactly once per set on the SUGGESTED→LOGGED edge.
    private func transition(ei: Int) {
        UnboundHaptics.success()
        startRest(ei: ei)
    }

    /// After loadContext resolves history/working-weight, fill each set's
    /// dim suggested weight via the existing SetPrefill ghost.
    private func applySuggestedWeights() {
        for ei in session.exercises.indices {
            for si in session.exercises[ei].sets.indices
            where session.exercises[ei].sets[si].suggestedWeightKg == nil {
                let fallbackWeight = ei == session.currentExerciseIndex ? workingWeightKg : nil
                if let g = SetPrefill.ghost(
                    exerciseName: session.exercises[ei].name,
                    setIndex: si,
                    priorEntries: priorEntries,
                    workingWeightKg: fallbackWeight) {
                    session.exercises[ei].sets[si].suggestedWeightKg = g.weightKg.map {
                        WeightPlatePolicy.snappedSuggestionKilograms(
                            $0,
                            unit: weightUnit,
                            microloadingEnabled: microloadingEnabled
                        )
                    }
                }
            }
        }
    }

    private func requestComplete() {
        if session.hasUnloggedWorkingSets {
            showCompleteConfirm = true
        } else {
            Task { await complete() }
        }
    }

    #if DEBUG
    private func debugFillPlannedSets() {
        session.objectWillChange.send()
        for exerciseIndex in session.exercises.indices where !session.exercises[exerciseIndex].skipped {
            for setIndex in session.exercises[exerciseIndex].sets.indices {
                guard !session.exercises[exerciseIndex].sets[setIndex].isWarmup else { continue }
                var set = session.exercises[exerciseIndex].sets[setIndex]
                switch session.exercises[exerciseIndex].metricKind {
                case .reps:
                    set.reps = set.suggestedReps ?? RepRange.lowerBound(session.exercises[exerciseIndex].plannedReps) ?? 8
                    set.weightKg = set.suggestedWeightKg ?? debugWeightKg(exerciseIndex: exerciseIndex, setIndex: setIndex)
                case .holdSeconds:
                    set.holdSeconds = set.suggestedHoldSeconds ?? 30
                case .durationSeconds:
                    set.durationSeconds = set.suggestedDurationSeconds ?? 600
                case .distanceMeters:
                    set.distanceMeters = set.suggestedDistanceMeters ?? 400
                case .calories:
                    set.calories = set.suggestedCalories ?? 20
                }
                set.rpe = set.suggestedRPE ?? session.exercises[exerciseIndex].targetRPE ?? 8
                set.logged = true
                session.exercises[exerciseIndex].sets[setIndex] = set
            }
        }
        try? draftStore.save(session)
        UnboundHaptics.success()
    }

    private func debugWeightKg(exerciseIndex: Int, setIndex: Int) -> Double {
        let base = 45 + (exerciseIndex * 15) + (setIndex * 2)
        return Double(base)
    }
    #endif

    // MARK: - Ghost prefill

    private func ghost(ei: Int, si: Int) -> SetPrefill.Ghost? {
        guard session.exercises.indices.contains(ei) else { return nil }
        return SetPrefill.ghost(
            exerciseName: session.exercises[ei].name,
            setIndex: si,
            priorEntries: priorEntries,
            workingWeightKg: workingWeightKg
        )
    }

    // MARK: - Intent handler

    private func handleIntent(_ ei: Int, _ intent: OverflowIntent) {
        if isRankTrial {
            switch intent {
            case .toggleWarmup, .editNotes:
                break
            case .addSet, .removeSet, .skipExercise, .swapExercise:
                return
            }
        }

        switch intent {
        case .toggleWarmup:
            if session.exercises.indices.contains(ei),
               let s0 = session.exercises[ei].sets.indices.first {
                session.exercises[ei].sets[s0].isWarmup.toggle()
            }

        case .addSet:
            session.addSet(toExerciseIndex: ei)

        case .removeSet:
            session.removeLastSet(fromExerciseIndex: ei)

        case .skipExercise:
            if session.exercises.indices.contains(ei) {
                session.exercises[ei].skipped = true
            }

        case .editNotes:
            notesEditingIndex = ei
            notesEditingText = session.exercises.indices.contains(ei)
                ? session.exercises[ei].notes : ""
            showNotesSheet = true
            return // draft save happens in the sheet's onSave closure

        case .swapExercise:
            guard session.exercises.indices.contains(ei) else { return }
            swapAlternatives = MovementCatalog.catalogAlternatives(to: session.exercises[ei].name)
            swapExerciseIndex = ei
            return // draft save happens in swap onSelect closure
        }
        try? draftStore.save(session)
    }

    // MARK: - Load context (wired to real APIs)

    private func loadContext() async {
        guard let uid = services.auth.currentUserId else { return }

        // Wire point 1: fetchRecentLogs(userId:limit:) exists on WorkoutLogServiceProtocol.
        // Flatten exerciseEntries from the 10 most-recent logs so SetPrefill can
        // find last-session values per exercise (most-recent last = .last(where:) picks latest).
        if let recentLogs = try? await services.workoutLog.fetchRecentLogs(userId: uid, limit: 10) {
            priorEntries = recentLogs
                .sorted { $0.startedAt < $1.startedAt } // oldest first → SetPrefill.last picks newest
                .flatMap { $0.exerciseEntries }
        }

        // Wire point 2: fetchWeight(userId:exerciseName:) returns WorkingWeight? with .weightKg:Double.
        // Use the normalized name (lowercased, spaces→"_") for the working-weight key.
        if let ex = session.currentExercise {
            let normalized = ex.name.lowercased().replacingOccurrences(of: " ", with: "_")
            if let ww = try? await services.workingWeight.fetchWeight(userId: uid, exerciseName: normalized) {
                workingWeightKg = ww.weightKg
            }
        }
        applySuggestedWeights()
    }

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    // MARK: - Save + reward

    private func complete() async {
        guard !saving else { return }
        guard let uid = services.auth.currentUserId else {
            // No session — don't trap the user behind a disabled dismiss.
            dismiss()
            return
        }
        saving = true
        #if DEBUG
        let performanceLog = session.assemblePerformanceLog(userId: uid, completedAt: DevProgramClock.now)
        #else
        let performanceLog = session.assemblePerformanceLog(userId: uid)
        #endif
        do {
            var completionResult = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
            let weeklyVowReceipt = services.trials.recordCompletedVowWork(
                performanceLog: performanceLog,
                completionResult: completionResult
            )
            if let weeklyVowReceipt {
                completionResult = await applyWeeklyVowBonus(
                    weeklyVowReceipt,
                    to: completionResult
                )
            }
            let rankTrialResult = OverallRankTrialRunner.shared.recordCompletedAttempt(
                performanceLog: performanceLog,
                completionResult: completionResult,
                bodyweightKg: (try? await services.user.fetchProfile(userId: uid))?.weightKg
            )
            HapticManager.notification(.success)
            restTimer.stop()
            draftStore.clear()
            // Finished training — drop squad presence so squadmates stop seeing
            // us as live (best-effort; the row also auto-expires after 3h).
            Task { await services.squadPresence.clearPresence(userId: uid) }

            let summary = makeRewardSequenceSummary(
                performanceLog: performanceLog,
                completionResult: completionResult,
                rankTrialResult: rankTrialResult,
                weeklyVowReceipt: weeklyVowReceipt
            )
            if totalLoggedWorkingSets > 0
                || summary.progression?.hasContent == true
                || summary.weeklyVowCallout != nil
                || summary.rankTrialCallout != nil {
                saving = false
                rewardSequence = summary
            } else {
                saving = false
                finishDismiss()
            }
        } catch {
            HapticManager.notification(.error)
            saving = false
            saveError = true   // surface it + offer Retry / Leave — never trap
        }
    }

    private func applyWeeklyVowBonus(
        _ receipt: WeeklyVowCompletionReceipt,
        to completionResult: TrainingCompletionResult
    ) async -> TrainingCompletionResult {
        var updated = completionResult
        do {
            let reward = try await OverallLevelService.shared.grantFlatXPStrict(
                amount: receipt.completionBonus.overallLevelXP,
                sourceId: "weekly-vow-bonus:\(receipt.performanceLogId)",
                userId: receipt.vow.userId,
                at: receipt.completedAt,
                database: services.database
            )
            updated.appendOverallLevelReward(reward)
        } catch {
            LoggingService.shared.log(
                "Weekly Vow bonus XP persistence failed: \(error)",
                level: .warning,
                context: [
                    "vowId": receipt.vow.id,
                    "performanceLogId": receipt.performanceLogId
                ]
            )
        }
        return updated
    }

    private func finishDismiss() {
        if let onFinished {
            onFinished()
        } else {
            dismiss()
        }
    }

    private func finishRewardSequence() {
        guard !isFinishingRewardSequence else { return }
        isFinishingRewardSequence = true
        rewardSequence = nil
        finishDismiss()
    }

    private func makeRewardSequenceSummary(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult,
        rankTrialResult: OverallRankTrialRunResult?,
        weeklyVowReceipt: WeeklyVowCompletionReceipt?
    ) -> WorkoutRewardSequenceSummary {
        let loggedSets = session.exercises
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup && $0.logged }
        let workSets = loggedSets.count
        let rewardSummary: RewardSummary? = {
            guard let rankUp = rankTrialResult?.rankUp else { return nil }
            var summary = RewardSummary()
            summary.rankUp = rankUp
            summary.skillTitle = rankUp.skillTitle
            summary.progression = completionResult.progressionReceipt
            return summary
        }()

        var summary = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: rewardSummary,
            fallbackXP: workSets * 12,
            sourceName: weeklyVowReceipt == nil ? session.source.rawValue.capitalized : "Binding Vow",
            weeklyVowCallout: weeklyVowReceipt?.callout
        )
        summary.rankTrialCallout = rankTrialResult.map(rankTrialCallout)
        return summary
    }

    private func rankTrialCallout(_ result: OverallRankTrialRunResult) -> RankTrialRewardCallout {
        let failed = result.evaluation.failedStation
        let clearedCount = result.evaluation.stationResults.filter { $0.status == .passed }.count
        let totalCount = result.evaluation.stationResults.count
        let detail = failed.map { station in
            station.failureReason.map { "\(station.title): \($0)" } ?? station.title
        } ?? "\(clearedCount)/\(totalCount) stations cleared"

        return RankTrialRewardCallout(
            id: result.attempt.id,
            title: result.definition.displayName,
            subtitle: result.attempt.passed ? "\(result.definition.targetRank.displayName) gate cleared" : "\(result.definition.targetRank.displayName) gate held",
            statusLine: result.attempt.passed ? "Official result saved" : "First failed station saved",
            detailLine: detail,
            receiptLine: "\(clearedCount)/\(totalCount) stations cleared",
            passed: result.attempt.passed
        )
    }
}

// MARK: - EditorSheet

/// Inline stepper sheet for editing a single weight or reps cell.
/// Writes back to session on Done; keeps `logged` state unchanged.
