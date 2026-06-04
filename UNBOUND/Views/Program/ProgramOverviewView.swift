import SwiftUI

// MARK: - ProgramOverviewView
//
// Three-tab surface for the user's training plan.
//
//   PROGRAM  — current-week strip + selected-day card (workout preview,
//              exercise list, BEGIN button for today).
//   ROUTINES — curated library of off-day / variety routines
//              (cardio, mobility, challenges, alt circuits). Placeholder
//              content until a real RoutineLibrary service ships.
//   RANKS    — current skill and exercise rank library.
//
// Taps on day tiles open DayDetailView as a preview (always preview-first,
// per user direction).

struct ProgramOverviewView: View {
    @EnvironmentObject var services: ServiceContainer

    /// Observe the singleton so TODAY'S TRAINING refreshes when the user
    /// flips a Program Focus from the skill detail screen. `@Bindable` here would
    /// require a @State container — using direct singleton access via
    /// `@Bindable var` on a property is the same pattern the skill detail
    /// view uses for SkillProgressService.
    @Bindable private var skillProgress = SkillProgressService.shared

    @State private var viewModel: ProgramViewModel?
    @State private var currentProfile: UserProfile?
    @State private var selectedTab: Tab = .program
    @State private var selectedDay: ProgramDay?
    @State private var showPaywall = false
    @State private var showRationale = false
    @State private var workoutReadyDraft: TrainingSessionDraft?
    @State private var activeWorkoutDraft: TrainingSessionDraft?
    @State private var sessionEditorDraft: TrainingSessionDraft?
    @State private var planningWorkoutDraft: TrainingSessionDraft?
    @State private var showSavedWorkouts = false
    @State private var schedulingSavedWorkout: SavedWorkout?
    @State private var schedulingDefaultDayNumbers: Set<Int> = []
    @State private var planningTargetDayNumber: Int?
    @State private var savedWorkoutScheduleError: SavedWorkoutScheduleError?
    @State private var recoveryRewardSequence: WorkoutRewardSequenceSummary?
    @State private var isCompletingRecoveryDay = false

    // Program Focus detail launcher state.
    @State private var pushedSkillNode: SkillNode?

    // V3 — day-strip preview + schedule editor sheets.
    @State private var previewDay: PreviewDay?
    @State private var showScheduleEditor: Bool = false
    @State private var focusSwitchPresentation: ProgramFocusSwitchPresentation?
    @State private var isSwitchingProgramFocus = false
    @State private var focusSwitchErrorMessage: String?

    // Program view state
    @State private var weekOffset: Int = 0 // +1 = next week, -1 = prev
    @State private var selectedDayDate: Date = Self.initialSelectedDayDate()
    #if DEBUG
    @State private var devDayOffset: Int = DevProgramClock.dayOffset
    #endif

    // Completed-log cache. Still feeds checkpoint/recovery context even
    // though the old calendar tab is no longer surfaced.
    @State private var pastLogs: [WorkoutLog] = []

    // Travel override (user hit the TRAVEL coach action)
    @State private var activeTravelOverride: TravelOverride?

    // Routines view state
    @State private var selectedRoutine: RoutineDef?
    @State private var activeRoutinePlayer: RoutineDef?
    @State private var selectedChallengeId: String = "daily-quest"
    @State private var selectedRoutineIdsByCategory: [RoutineCategory: String] = [:]
    @State private var travelingRoutine: RoutineDef?
    @State private var routineTravelProgress: CGFloat = 0
    #if DEBUG
    @State private var debugOpenedRoutine = false
    #endif

    // Block rollover (Chunk 3): block-complete CTA + optional rescan + share.
    @State private var isGeneratingNextBlock: Bool = false
    @State private var showRescanFlow: Bool = false
    @State private var showCheckpointFlow: Bool = false
    @State private var rolloverDeltaReport: ScanDeltaReport?
    @State private var rolloverProposal: BlockRolloverService.ProgramBlockProposal?
    @State private var showProgressReveal: Bool = false
    @State private var nextBlockNumberPreview: Int = 2
    @State private var currentBlockNumberPreview: Int = 1

    // Resume draft affordance.
    @State private var resumeDraft: ActiveWorkoutSession?
    private let draftStore = WorkoutDraftStore()

    enum Tab: Hashable { case program, routines, ranks }

    private static func initialSelectedDayDate() -> Date {
        #if DEBUG
        return DevProgramClock.today
        #else
        return Calendar.current.startOfDay(for: Date())
        #endif
    }

    private var programToday: Date {
        #if DEBUG
        return DevProgramClock.today(offset: devDayOffset)
        #else
        return Calendar.current.startOfDay(for: Date())
        #endif
    }

    private var programNow: Date {
        #if DEBUG
        return DevProgramClock.now(offset: devDayOffset)
        #else
        return Date()
        #endif
    }

    private func isProgramToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: programToday)
    }

    private func isProgramPast(_ date: Date) -> Bool {
        date < programToday && !isProgramToday(date)
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                tabSelector
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Group {
                    switch selectedTab {
                    case .program:  programTab
                    case .routines: routinesTab
                    case .ranks:    ProgramRankLibraryView()
                    }
                }
            }

            if let travelingRoutine {
                RoutineTravelOverlay(routine: travelingRoutine, progress: routineTravelProgress)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(3)
            }

            if isCompletingRecoveryDay {
                recoveryCompletionOverlay
                    .transition(.opacity)
                    .zIndex(4)
            }

            if let recoveryRewardSequence {
                WorkoutRewardSequenceView(summary: recoveryRewardSequence) {
                    UnboundHaptics.medium()
                    self.recoveryRewardSequence = nil
                }
                .interactiveDismissDisabled(true)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(5)
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadProgramSurface()

            #if DEBUG
            openRoutineForProofIfRequested()
            #endif
        }
        .sheet(isPresented: $showPaywall) {
            PaywallPlaceholderView()
                .environmentObject(services)
        }
        .sheet(isPresented: $showRationale) {
            if let rationale = viewModel?.program?.rationale {
                WhyThisProgramView(rationale: rationale, onDismiss: { showRationale = false })
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showSavedWorkouts) {
            SavedWorkoutsListView(
                onCreateNew: {
                    showSavedWorkouts = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        openPlanAheadEditor()
                    }
                },
                onReplaceToday: { workout in
                    showSavedWorkouts = false
                    replaceTodayWithSavedWorkout(workout)
                },
                onSchedule: { workout in
                    showSavedWorkouts = false
                    schedulingDefaultDayNumbers = []
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        schedulingSavedWorkout = workout
                    }
                },
                onDismiss: {
                    showSavedWorkouts = false
                }
            )
        }
        .sheet(item: $schedulingSavedWorkout) { workout in
            if let program = viewModel?.program {
                ScheduleSavedWorkoutSheet(
                    savedWorkout: workout,
                    program: program,
                    minimumDayNumber: currentProgramDayNumber(in: program),
                    preselectedDayNumbers: schedulingDefaultDayNumbers,
                    onSchedule: { dayNumbers in
                        schedulingSavedWorkout = nil
                        schedulingDefaultDayNumbers = []
                        scheduleSavedWorkout(
                            workout,
                            dayNumbers: dayNumbers,
                            replacingCustomizedDays: false
                        )
                    },
                    onDismiss: {
                        schedulingSavedWorkout = nil
                        schedulingDefaultDayNumbers = []
                    }
                )
            }
        }
        .alert(item: $savedWorkoutScheduleError) { error in
            Alert(
                title: Text("Saved Workout"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .fullScreenCover(item: $workoutReadyDraft) { draft in
            WorkoutReadyView(draft: draft)
                .environmentObject(services)
        }
        .fullScreenCover(item: $activeWorkoutDraft) { draft in
            ActiveWorkoutContainerView(draft: draft, services: services) {
                UserDefaults.standard.set(0, forKey: "unbound.shortSessionDate")
                activeWorkoutDraft = nil
                Task { await refreshHistory() }
            }
            .environmentObject(services)
        }
        .fullScreenCover(item: $sessionEditorDraft) { draft in
            SessionEditorView(draft: draft) { editedDraft in
                sessionEditorDraft = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    activeWorkoutDraft = editedDraft
                }
            }
            .environmentObject(services)
        }
        .fullScreenCover(item: $planningWorkoutDraft) { draft in
            SessionEditorView(draft: draft, mode: .planAhead) { editedDraft in
                savePlannedWorkoutAndOpenSchedule(editedDraft)
            }
            .environmentObject(services)
        }
        .navigationDestination(item: $selectedDay) { day in
            DayDetailView(
                day: day,
                nutritionPlan: viewModel?.dailyNutrition,
                recoveryPlan: viewModel?.recoveryPlan,
                workoutLog: viewModel?.logFor(dayNumber: day.dayNumber),
                programViewModel: viewModel,
                programId: viewModel?.program?.id ?? ""
            )
        }
        .fullScreenCover(item: $activeRoutinePlayer) { routine in
            RoutineCompletionFlow(routine: routine) {
                activeRoutinePlayer = nil
                Task { await refreshHistory() }
            }
            .environmentObject(services)
        }
        .fullScreenCover(item: $pushedSkillNode) { node in
            NavigationStack {
                SkillDetailView(
                    node: node,
                    graph: SkillGraph.shared,
                    nodeStates: skillProgress.nodeStates
                )
            }
        }
        .sheet(item: $previewDay) { wrapper in
            DayPreviewSheet(
                date: wrapper.date,
                onSelectSkill: { node in
                    previewDay = nil
                    pushedSkillNode = node
                },
                onTrainSkill: { node in
                    previewDay = nil
                    launchSkillReadyDraft(node)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showScheduleEditor) {
            WeeklyScheduleEditorSheet()
                .environmentObject(services)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $focusSwitchPresentation) { presentation in
            ProgramFocusSwitchSheet(
                currentStyle: presentation.currentStyle,
                currentEquipment: presentation.currentEquipment,
                currentExperience: presentation.currentExperience,
                isApplying: isSwitchingProgramFocus,
                errorMessage: focusSwitchErrorMessage,
                onApply: { selection in
                    Task { await applyFocusSwitch(selection) }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showRescanFlow) {
            PhotoCaptureFlow(mode: .scan) { _ in
                showRescanFlow = false
                // After a rescan, refresh the delta-report cache so the
                // block-complete teaser reflects the new comparison.
                if let program = viewModel?.program {
                    Task { await loadBlockRolloverContext(program: program) }
                }
            }
            .environmentObject(services)
        }
        .sheet(isPresented: $showCheckpointFlow) {
            CheckpointFlowSheet(
                nutritionContext: checkpointNutritionContext,
                missedSessionSignal: checkpointMissedSessionSignal,
                onCaptureBodyScan: {
                    showRescanFlow = true
                },
                onCommit: { outcome in
                    showCheckpointFlow = false
                    Task { await applyCheckpointOutcome(outcome) }
                },
                onDismiss: {
                    showCheckpointFlow = false
                }
            )
        }
    }

    @MainActor
    private func loadProgramSurface() async {
        let vm = ProgramViewModel(services: services)
        self.viewModel = vm

        #if DEBUG
        if let override = ProgramSurfaceProofOverride.fromLaunchArguments() {
            vm.state = override.loadingState
            return
        }
        #endif

        guard let userId = services.auth.currentUserId else { return }

        // History + travel don't depend on the profile — run concurrently.
        async let historyDone: Void = refreshHistory()
        async let travelDone: Void = refreshTravelOverride()

        // Instant: paint today's program from the local store — zero
        // network before the screen appears.
        let store = ProgramStore.shared
        let cached = store.loadLocal(userId: userId)
        if let cached {
            vm.program = cached
            vm.state = .loaded(cached)
            await vm.loadTrackingData()
            vm.refreshWaveAdjustments(asOf: selectedDayDate)
        }

        // Background: learn the authoritative programId; reconcile only
        // if a new program (rollover) superseded the cache, or load/
        // generate when there was no cache (first run).
        do {
            let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
            self.currentProfile = profile
            if let programId = profile.currentProgramId {
                if cached == nil {
                    await vm.loadProgram(programId: programId)
                } else {
                    await store.revalidate(userId: userId, expectedProgramId: programId)
                    if let refreshed = store.program, refreshed.id != cached?.id {
                        vm.program = refreshed
                        vm.state = .loaded(refreshed)
                        await vm.loadTrackingData()
                        vm.refreshWaveAdjustments(asOf: selectedDayDate)
                    }
                }
            } else if cached == nil {
                vm.state = .loading
                let generated = try await ProgramGenerationService.shared.generateFromOnboarding(
                    userId: userId,
                    targetFrequency: profile.targetFrequency,
                    equipment: Set(profile.equipment ?? []),
                    experience: profile.experience,
                    sessionLength: profile.sessionLength,
                    exerciseStyles: Set(profile.exerciseStyles ?? []),
                    targetAreas: Set(profile.targetAreas ?? []),
                    age: profile.age ?? 0,
                    gender: profile.gender ?? .unspecified,
                    heightCm: profile.heightCm ?? 0,
                    weightKg: profile.weightKg ?? 0,
                    trainingDays: profile.trainingDays,
                    trainingStyleOverride: profile.trainingStyleOverride,
                    trainingFeedbackMode: profile.trainingFeedbackMode,
                    cutModeActive: profile.cutMode.enabled,
                    biologicalSex: profile.biologicalSex
                )
                vm.program = generated
                vm.state = .loaded(generated)
                store.adopt(generated, userId: userId)
                vm.refreshWaveAdjustments(asOf: selectedDayDate)
            }
        } catch {
            if cached == nil {
                vm.state = .error(.databaseReadFailed(underlying: error))
            }
        }

        _ = await historyDone
        _ = await travelDone

        // Prefetch today's session for every Program Focus so tapping
        // TRAIN is instant. Each in its own detached task.
        for focusId in skillProgress.programFocusIds {
            Task.detached { @MainActor in
                await RPESessionService.shared.prefetch(
                    skillId: focusId,
                    userId: userId
                )
            }
        }
    }

    // MARK: - V3 day-preview wrapper
    //
    // Sheet(item:) needs Identifiable but Date isn't, so wrap it.
    fileprivate struct PreviewDay: Identifiable, Hashable {
        let date: Date
        var id: Date { date }
    }

    private struct SavedWorkoutScheduleError: Identifiable {
        let id = UUID()
        let message: String
    }

    // MARK: - TODAY'S TRAINING (Program Focuses)
    //
    // V1: surfaces every Program Focus every day. Each row launches the
    // existing deterministic `SkillSessionView` directly — tapping the
    // card body navigates into `SkillDetailView` instead. State copy is
    // computed live from `SkillProgressService.canTrain` so the row
    // flips from "Ready" → "Trained today" without a refresh.

    private var todaysTrainingSection: some View {
        let scheduler = ProgramScheduler.shared
        let todayDate = programToday
        let skillIds = scheduler.todaysSkillSessions(on: todayDate)
        let routedCount = skillIds.count
        let totalFocuses = skillProgress.programFocusIds.count
        let todayCat = scheduler.category(for: todayDate)
        let week = scheduler.weeklyOverview(startingAt: todayDate)

        return VStack(alignment: .leading, spacing: 8) {
            // Header — 2-line: "MONDAY · PULL DAY" + count summary, plus
            // an EDIT SCHEDULE pill on the right (V3).
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerLine1(for: todayDate, category: todayCat))
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.accent)
                    Text(headerLine2(routedCount: routedCount, totalFocuses: totalFocuses, category: todayCat))
                        .font(Font.unbound.captionS)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer(minLength: 6)
                editScheduleButton
            }

            // Body — either routed focus cards, or a quiet empty state.
            if skillIds.isEmpty {
                routedEmptyState(category: todayCat, week: week)
            } else {
                VStack(spacing: 8) {
                    ForEach(skillIds, id: \.self) { id in
                        if let node = SkillGraph.shared.node(id: id) {
                            programFocusCard(node: node)
                        }
                    }
                }
            }

            // 7-day horizontal strip.
            weeklyDayStrip(week: week)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - TODAY'S TRAINING helpers

    private func headerLine1(for date: Date, category: DayCategory) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let weekday = f.string(from: date).uppercased()
        if category == .rest {
            return "\(weekday) · REST DAY"
        }
        return "\(weekday) · \(category.displayName.uppercased()) DAY"
    }

    private func headerLine2(routedCount: Int, totalFocuses: Int, category: DayCategory) -> String {
        if totalFocuses == 0 {
            return "No Program Focuses yet"
        }
        if category == .rest {
            return "Recovery is the work"
        }
        let focusWord = totalFocuses == 1 ? "focus" : "focuses"
        return "\(routedCount) of \(totalFocuses) \(focusWord) routed today"
    }

    @ViewBuilder
    private func routedEmptyState(
        category: DayCategory,
        week: [(date: Date, category: DayCategory, count: Int)]
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: category == .rest ? "moon.fill" : "calendar.badge.clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(category == .rest ? "Rest day" : "No focuses routed to \(category.displayName) day")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(emptyStateSubcopy(category: category, week: week))
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func emptyStateSubcopy(
        category: DayCategory,
        week: [(date: Date, category: DayCategory, count: Int)]
    ) -> String {
        if category == .rest {
            return "Recover hard so tomorrow lands."
        }
        // Find next routed day with at least one focus.
        let next = week.dropFirst().first(where: { $0.count > 0 })
        guard let next else {
            return "Add Program Focuses from any skill detail screen."
        }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let weekday = f.string(from: next.date)
        return "Your \(next.category.displayName) focuses resume \(weekday)."
    }

    // MARK: - 7-day strip

    private func weeklyDayStrip(
        week: [(date: Date, category: DayCategory, count: Int)]
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, slot in
                dayStripChip(date: slot.date, category: slot.category, count: slot.count)
            }
        }
    }

    private func dayStripChip(date: Date, category: DayCategory, count: Int) -> some View {
        let cal = Calendar.current
        let isToday = isProgramToday(date)
        let letter = singleLetterWeekday(for: date)
        let isRest = category == .rest

        return Button {
            UnboundHaptics.soft()
            previewDay = PreviewDay(date: cal.startOfDay(for: date))
        } label: {
            VStack(spacing: 4) {
                Text(letter)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(isToday ? Color.unbound.accent : Color.unbound.textTertiary)

                Image(systemName: category.glyph)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        isRest
                            ? Color.unbound.textTertiary
                            : (isToday ? Color.unbound.accent : Color.unbound.textSecondary)
                    )

                // Count badge — show non-zero count, blank for 0/rest.
                Group {
                    if count > 0 {
                        Text("\(count)")
                            .font(Font.unbound.captionS.weight(.bold))
                            .foregroundStyle(isToday ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                            .monospacedDigit()
                    } else {
                        Text(" ")
                            .font(Font.unbound.captionS.weight(.bold))
                    }
                }
                .frame(height: 12)
            }
            .frame(width: 40, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isToday
                            ? Color.unbound.accent.opacity(0.16)
                            : Color.unbound.surfaceElevated.opacity(0.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isToday
                            ? Color.unbound.accent.opacity(0.6)
                            : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - V3 EDIT SCHEDULE pill

    private var editScheduleButton: some View {
        Button {
            UnboundHaptics.soft()
            showScheduleEditor = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 9, weight: .bold))
                Text("EDIT")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
            }
            .foregroundStyle(Color.unbound.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.unbound.surfaceElevated.opacity(0.6))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func singleLetterWeekday(for date: Date) -> String {
        let cal = Calendar.current
        // 1=Sun, 2=Mon, ..., 7=Sat
        let wd = cal.component(.weekday, from: date)
        switch wd {
        case 1: return "S"
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "T"
        case 6: return "F"
        case 7: return "S"
        default: return "?"
        }
    }

    private func programFocusCard(node: SkillNode) -> some View {
        let canTrain = skillProgress.canTrain(nodeId: node.id)
        let stateLabel = canTrain ? "Ready" : "Trained today"
        let buttonLabel = canTrain ? "TRAIN" : "VIEW"
        let asset = SkillTraditionalVisualResolver.assetName(for: node)
        let usesExistingCharacterArt = asset?.hasPrefix("exercise_visual_") == true

        return Button {
            UnboundHaptics.soft()
            pushedSkillNode = node
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(usesExistingCharacterArt ? Color.white : Color.unbound.surfaceElevated)
                        .frame(width: 56, height: 56)
                    if let asset, UIImage(named: asset) != nil {
                        Image(asset)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .padding(usesExistingCharacterArt ? 5 : 0)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: node.glyph)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.unbound.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Text("\(node.cluster.displayName) · \(stateLabel)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(canTrain ? Color.unbound.textSecondary : Color.unbound.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Button {
                    UnboundHaptics.medium()
                    if canTrain {
                        launchSkillReadyDraft(node)
                    } else {
                        pushedSkillNode = node
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(buttonLabel)
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.2)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(canTrain ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(canTrain ? Color.unbound.accent : Color.unbound.surfaceElevated)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                canTrain ? Color.clear : Color.unbound.borderSubtle,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("PROGRAM")
                .font(Font.unbound.titleS)
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textPrimary)
            Spacer()
            Button {
                UnboundHaptics.soft()
                showSavedWorkouts = true
            } label: {
                Image(systemName: "tray.full")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Saved Workouts")
            .accessibilityIdentifier("program.savedWorkouts")
            Button {
                UnboundHaptics.soft()
                openPlanAheadEditor()
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Plan Workout Ahead")
            .accessibilityIdentifier("program.customWorkout")
            Button {
                UnboundHaptics.soft()
                if viewModel?.program?.rationale != nil { showRationale = true }
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func emptyCustomWorkoutDraft(
        title: String = "Planned Workout",
        date: Date? = nil
    ) -> TrainingSessionDraft? {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Custom workout launch skipped without authenticated user",
                level: .warning
            )
            return nil
        }
        return TrainingSessionDraft(
            userId: userId,
            source: .custom,
            title: title,
            date: date ?? programToday,
            estimatedMinutes: 10,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Main Work",
                    prescriptions: []
                )
            ]
        )
    }

    private func openPlanAheadEditor() {
        guard let draft = emptyCustomWorkoutDraft(date: planningDraftDate()) else { return }
        planningTargetDayNumber = planningDefaultDayNumber()
        planningWorkoutDraft = draft
    }

    private func planningDraftDate() -> Date {
        isProgramPast(selectedDayDate) ? programToday : selectedDayDate
    }

    private func planningDefaultDayNumber() -> Int? {
        guard let program = viewModel?.program,
              !isProgramPast(selectedDayDate),
              let day = programDay(for: selectedDayDate, in: program),
              !day.isRestDay
        else { return nil }
        return day.dayNumber
    }

    private func savePlannedWorkoutAndOpenSchedule(_ draft: TrainingSessionDraft) {
        var cleanDraft = draft
        let title = cleanDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanDraft.title = title.isEmpty ? "Planned Workout" : title

        let savedWorkout = SavedWorkout.from(cleanDraft, title: cleanDraft.title, now: Date())
        SavedWorkoutStore.shared.save(savedWorkout)
        schedulingDefaultDayNumbers = planningTargetDayNumber.map { Set([$0]) } ?? []
        planningTargetDayNumber = nil
        planningWorkoutDraft = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            schedulingSavedWorkout = savedWorkout
        }
    }

    private func replaceTodayWithSavedWorkout(_ workout: SavedWorkout) {
        guard let program = viewModel?.program,
              let day = programDay(for: programToday, in: program)
        else {
            savedWorkoutScheduleError = SavedWorkoutScheduleError(message: "No active Program day was available.")
            return
        }

        scheduleSavedWorkout(
            workout,
            dayNumbers: [day.dayNumber],
            replacingCustomizedDays: true
        )
    }

    private func scheduleSavedWorkout(
        _ workout: SavedWorkout,
        dayNumbers: [Int],
        replacingCustomizedDays: Bool
    ) {
        Task {
            do {
                try await viewModel?.scheduleSavedWorkout(
                    workout,
                    on: dayNumbers,
                    replacingCustomizedDays: replacingCustomizedDays
                )
            } catch {
                await MainActor.run {
                    savedWorkoutScheduleError = SavedWorkoutScheduleError(
                        message: "That Saved Workout could not be scheduled here. Pick another day or replace the existing custom slot."
                    )
                }
            }
        }
    }

    private func launchSkillReadyDraft(_ node: SkillNode) {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Blocked skill-ready draft launch without an authenticated user",
                level: .warning,
                context: ["skillId": node.id]
            )
            pushedSkillNode = node
            return
        }
        workoutReadyDraft = DailyWorkoutResolver.skillOnlyDraft(skillId: node.id, userId: userId)
    }

    private func launchWorkoutReady(for day: ProgramDay, date: Date) {
        guard let workout = day.workout else {
            selectedDay = day
            return
        }

        workoutReadyDraft = programDraft(from: workout, day: day, date: date)
    }

    private func launchSessionEditor(for day: ProgramDay, date: Date) {
        guard let workout = day.workout else {
            selectedDay = day
            return
        }

        sessionEditorDraft = programDraft(from: workout, day: day, date: date)
    }

    private func launchActiveWorkout(for day: ProgramDay, date: Date) {
        guard let workout = day.workout else {
            selectedDay = day
            return
        }

        activeWorkoutDraft = programDraft(from: workout, day: day, date: date)
    }

    @MainActor
    private func completeRecoveryDay(_ day: ProgramDay) async {
        guard !isCompletingRecoveryDay, recoveryRewardSequence == nil else { return }
        guard let viewModel else {
            selectedDay = day
            return
        }

        isCompletingRecoveryDay = true
        do {
            if let completion = try await viewModel.completeRestDay(day, at: selectedDayDate) {
                UnboundHaptics.success()
                recoveryRewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
                    performanceLog: completion.performanceLog,
                    completionResult: completion.result,
                    sourceName: "Recovery"
                )
            } else {
                selectedDay = day
            }
        } catch {
            LoggingService.shared.log(
                "Rest day recovery completion failed: \(error)",
                level: .warning,
                context: ["dayNumber": day.dayNumber]
            )
            selectedDay = day
        }
        isCompletingRecoveryDay = false
    }

    private var recoveryCompletionOverlay: some View {
        ZStack {
            Color.unbound.bg.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(Color.unbound.rankGold)
                    .scaleEffect(1.12)
                Text("LOCKING RECOVERY")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.rankGold)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.rankGold.opacity(0.32), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("program.recoveryCompleting")
    }

    private func programDraft(from workout: Workout, day: ProgramDay, date: Date) -> TrainingSessionDraft? {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Program draft launch skipped without authenticated user",
                level: .warning,
                context: ["dayNumber": day.dayNumber]
            )
            return nil
        }
        return DailyWorkoutResolver.programDraft(
            from: workout,
            userId: userId,
            programId: viewModel?.program?.id,
            dayNumber: day.dayNumber,
            date: date
        )
    }

    // MARK: - Tab selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabChip(.program, label: "PROGRAM")
            tabChip(.routines, label: "ROUTINES")
            tabChip(.ranks, label: "RANKS")
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.unbound.surface)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func tabChip(_ tab: Tab, label: String) -> some View {
        let isActive = selectedTab == tab
        return Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(label)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(isActive ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive ? Color.unbound.accent.opacity(0.25) : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    #if DEBUG
    private var devDaySimulatorCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DEV DAY SIM")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.7)
                    .foregroundStyle(Color.unbound.accent)
                HStack(spacing: 6) {
                    Text(devDayOffsetLabel)
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(devDayDateLabel)
                        .font(Font.unbound.captionS)
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                devDayButton(systemName: "chevron.left", identifier: "program.devDaySim.previous") {
                    moveSimulatedDay(by: -1)
                }
                Button {
                    resetSimulatedDay()
                } label: {
                    Text("RESET")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 58, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.unbound.surfaceElevated)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("program.devDaySim.reset")
                devDayButton(systemName: "chevron.right", identifier: "program.devDaySim.next") {
                    moveSimulatedDay(by: 1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    DevProgramClock.isSimulating
                        ? Color.unbound.accent.opacity(0.45)
                        : Color.unbound.borderSubtle,
                    lineWidth: 1
                )
        )
        .accessibilityIdentifier("program.devDaySim")
    }

    private var devDayOffsetLabel: String {
        if devDayOffset == 0 { return "REAL TODAY" }
        return devDayOffset > 0 ? "D+\(devDayOffset)" : "D\(devDayOffset)"
    }

    private var devDayDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: programToday).uppercased()
    }

    private func devDayButton(
        systemName: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func moveSimulatedDay(by days: Int) {
        UnboundHaptics.soft()
        devDayOffset = DevProgramClock.advance(days: days)
        syncSelectedDayToSimulatedToday()
    }

    private func resetSimulatedDay() {
        UnboundHaptics.soft()
        devDayOffset = DevProgramClock.reset()
        syncSelectedDayToSimulatedToday()
    }

    private func syncSelectedDayToSimulatedToday() {
        let today = programToday
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedDayDate = today
            weekOffset = 0
        }
        viewModel?.refreshWaveAdjustments(asOf: today)
        Task {
            await refreshHistory()
            await refreshTravelOverride()
        }
    }
    #endif

    private var savedWorkoutsEntryCard: some View {
        let workouts = SavedWorkoutStore.shared.all()
        let latest = workouts.first
        let count = workouts.count

        return VStack(spacing: 10) {
            Button {
                UnboundHaptics.soft()
                showSavedWorkouts = true
            } label: {
                HStack(spacing: 12) {
                    savedWorkoutEntryVisual(for: latest)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text("SAVED WORKOUTS")
                                .font(Font.unbound.captionS.weight(.heavy))
                                .tracking(1.5)
                                .foregroundStyle(Color.unbound.coachCyan)
                            Text(count == 0 ? "EMPTY" : "\(count)")
                                .font(Font.unbound.monoS.weight(.bold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .padding(.horizontal, 7)
                                .frame(height: 20)
                                .background(Capsule().fill(Color.unbound.coachCyan.opacity(0.14)))
                        }
                        Text(latest?.title ?? "Saved")
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("program.savedWorkouts.open")

            HStack(spacing: 10) {
                Button {
                    UnboundHaptics.soft()
                    openPlanAheadEditor()
                } label: {
                    Label("Plan", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ProgramQuickActionButtonStyle(tint: Color.unbound.accent))
                .accessibilityIdentifier("program.planAhead")

                Button {
                    UnboundHaptics.soft()
                    showSavedWorkouts = true
                } label: {
                    Label("Saved", systemImage: "tray.full")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ProgramQuickActionButtonStyle(tint: Color.unbound.coachCyan))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(0.22), lineWidth: 1)
        )
        .accessibilityIdentifier("program.savedWorkouts.card")
    }

    @ViewBuilder
    private func savedWorkoutEntryVisual(for workout: SavedWorkout?) -> some View {
        if let definition = workout?.primaryMovementDefinition {
            ExerciseVisualView(definition: definition, size: .thumbnail)
                .frame(width: 54, height: 54)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                Image(systemName: "tray.full")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.unbound.coachCyan)
            }
            .frame(width: 54, height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
    }

    private struct ProgramQuickActionButtonStyle: ButtonStyle {
        let tint: Color

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(Font.unbound.captionS.weight(.heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(height: 38)
                .background(
                    Capsule().fill(tint.opacity(configuration.isPressed ? 0.18 : 0.10))
                )
                .overlay(
                    Capsule().strokeBorder(tint.opacity(configuration.isPressed ? 0.36 : 0.24), lineWidth: 1)
                )
        }
    }

    // MARK: - PROGRAM tab

    @ViewBuilder
    private var programTab: some View {
        if let vm = viewModel {
            let surfaceState = ProgramSurfaceState.resolve(
                state: vm.state,
                selectedDate: selectedDayDate,
                now: programNow
            )
            switch surfaceState.kind {
            case .noProgram:
                noProgramState
            case .loading:
                ProgressView().tint(Color.unbound.accent).frame(maxHeight: .infinity)
            case .loadError:
                errorState(vm.state.errorValue)
            case .blockComplete:
                if let program = vm.state.value {
                    blockCompleteState(program: program)
                } else {
                    errorState(nil)
                }
            case .restDay, .trainingDay, .missingDay:
                if let program = vm.state.value {
                    programBody(program)
                } else {
                    noProgramState
                }
            }
        } else {
            ProgressView().tint(Color.unbound.accent).frame(maxHeight: .infinity)
        }
    }

    // MARK: - Block-complete state (Chunk 3)
    //
    // Surfaces when the current 28-day block has elapsed. Shows a single
    // premium card with one primary CTA ("BUILD BLOCK N+1") and a secondary
    // RESCAN affordance. Pulls the latest ScanDeltaReport (if any) so we can
    // surface a small "what changed" teaser before the user commits.

    @ViewBuilder
    private func blockCompleteState(program: TrainingProgram) -> some View {
        let nextBlock = nextBlockNumberPreview
        let currentBlock = currentBlockNumberPreview
        let arc = arcLabel(for: nextBlock)

        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                blockCompleteHeader(currentBlock: currentBlock)

                blockCompleteSummary(
                    program: program,
                    currentBlock: currentBlock,
                    nextBlock: nextBlock,
                    arc: arc
                )

                if let delta = rolloverDeltaReport {
                    blockCompleteProgressTeaser(delta: delta, nextBlock: nextBlock)
                }

                if let proposal = rolloverProposal {
                    blockProposalCard(proposal)
                }

                blockCompleteActions(
                    program: program,
                    nextBlock: nextBlock
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task { await loadBlockRolloverContext(program: program) }
        .sheet(isPresented: $showProgressReveal) {
            if let delta = rolloverDeltaReport {
                BlockProgressRevealView(
                    deltaReport: delta,
                    blockNumber: currentBlock,
                    nextBlockNumber: nextBlock,
                    onBuildNextBlock: {
                        showProgressReveal = false
                        Task { await runGenerateNextBlock(currentProgram: program) }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func blockCompleteHeader(currentBlock: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BLOCK COMPLETE")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(Color.unbound.accent)
            Text("28 days. Block \(currentBlock) done.")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func blockCompleteSummary(
        program: TrainingProgram,
        currentBlock: Int,
        nextBlock: Int,
        arc: String
    ) -> some View {
        let trainedDays = trainedDayCount(in: program)
        let totalDays = program.durationDays
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(trainedDays)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("/ \(totalDays) sessions logged")
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Text(blockArcSummary(arc: arc, currentBlock: currentBlock, nextBlock: nextBlock))
                .font(Font.unbound.bodyL)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func blockCompleteProgressTeaser(delta: ScanDeltaReport, nextBlock: Int) -> some View {
        Button {
            UnboundHaptics.soft()
            showProgressReveal = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis.ascending")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                    Text("PROGRESS SNAPSHOT")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Text(blockProgressTeaser(delta: delta, nextBlock: nextBlock))
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func blockProposalCard(_ proposal: BlockRolloverService.ProgramBlockProposal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                Text("NEXT BLOCK PROPOSAL")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                Text("BLOCK \(proposal.nextBlockNumber)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(proposal.lines.prefix(4).enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: proposalIcon(for: line.kind))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(proposalColor(for: line.kind))
                            .frame(width: 16)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.title)
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(2)
                            Text(line.detail)
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func proposalIcon(for kind: BlockRolloverService.ProgramBlockProposal.Line.Kind) -> String {
        switch kind {
        case .scan: return "camera.metering.center.weighted"
        case .focus: return "scope"
        case .carryForward: return "arrow.forward.circle"
        case .rotation: return "arrow.triangle.2.circlepath"
        case .rescan: return "camera.viewfinder"
        }
    }

    private func proposalColor(for kind: BlockRolloverService.ProgramBlockProposal.Line.Kind) -> Color {
        switch kind {
        case .scan, .focus: return Color.unbound.accent
        case .rotation, .rescan: return Color.unbound.warnOrange
        case .carryForward: return Color.unbound.textSecondary
        }
    }

    private func blockCompleteActions(program: TrainingProgram, nextBlock: Int) -> some View {
        VStack(spacing: 12) {
            Button {
                UnboundHaptics.soft()
                Task { await runGenerateNextBlock(currentProgram: program) }
            } label: {
                HStack(spacing: 8) {
                    if isGeneratingNextBlock {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Color.unbound.textPrimary)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(isGeneratingNextBlock ? "BUILDING…" : "BUILD BLOCK \(nextBlock)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .tracking(1.6)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingNextBlock)

            Button {
                UnboundHaptics.soft()
                showCheckpointFlow = true
            } label: {
                Text("CHECKPOINT FIRST")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingNextBlock)
        }
    }

    // MARK: - Block-complete data + actions

    /// Pull block number + latest delta report so the CTA + teaser are
    /// populated when the block-complete card first appears.
    private func loadBlockRolloverContext(program: TrainingProgram) async {
        guard let userId = services.auth.currentUserId else { return }

        let latest = await ProgramBlockStore.shared.latestBlock(userId: userId)
        let resolvedCurrent = max(latest?.blockNumber ?? 1, 1)
        let resolvedNext = resolvedCurrent + 1

        let delta: ScanDeltaReport? = await {
            do {
                let results: [ScanDeltaReport] = try await services.database.query(
                    collection: "scanDeltaReports",
                    field: "userId",
                    isEqualTo: userId,
                    orderBy: "createdAt",
                    descending: true,
                    limit: 1
                )
                return results.first
            } catch {
                return nil
            }
        }()

        await MainActor.run {
            self.currentBlockNumberPreview = resolvedCurrent
            self.nextBlockNumberPreview = resolvedNext
            self.rolloverDeltaReport = delta
            self.rolloverProposal = BlockRolloverService.proposal(
                currentBlockNumber: resolvedCurrent,
                previousBlock: latest,
                latestDeltaReport: delta
            )
        }
    }

    /// Drives the BUILD BLOCK N CTA: spinner → generate → swap state to the
    /// new program. Failures restore the loaded state silently so the user
    /// can retry; production telemetry catches the failure path.
    private func runGenerateNextBlock(currentProgram: TrainingProgram) async {
        guard let vm = viewModel,
              let userId = services.auth.currentUserId,
              !isGeneratingNextBlock else { return }

        isGeneratingNextBlock = true
        let restoreState: LoadingState<TrainingProgram> = vm.state
        vm.state = .loading

        do {
            let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
            let previousBlock = await ProgramBlockStore.shared.latestBlock(userId: userId)
            let proposal = rolloverProposal ?? BlockRolloverService.proposal(
                currentBlockNumber: currentBlockNumberPreview,
                previousBlock: previousBlock,
                latestDeltaReport: rolloverDeltaReport
            )
            let proposalAnalysis = BlockRolloverService.analysis(from: proposal, userId: userId)
            let newProgram = try await BlockRolloverService.performRollover(
                userId: userId,
                profile: profile,
                analysis: proposalAnalysis,
                scan: nil
            )
            vm.program = newProgram
            vm.state = .loaded(newProgram)
            await vm.loadTrackingData()
        } catch {
            services.logging.log(
                "BlockRolloverService.performRollover failed: \(error)",
                level: .error,
                context: ["currentProgramId": currentProgram.id]
            )
            vm.state = restoreState
        }

        isGeneratingNextBlock = false
    }

    // MARK: - Block-complete copy helpers

    private func arcLabel(for blockNumber: Int) -> String {
        // Mirrors the deterministic generator's 3-arc copy cycle.
        let arc = ((max(blockNumber, 1) - 1) % 3) + 1
        switch arc {
        case 1: return "accumulation"
        case 2: return "intensification"
        case 3: return "realization"
        default: return "accumulation"
        }
    }

    private func trainedDayCount(in program: TrainingProgram) -> Int {
        guard let vm = viewModel else { return 0 }
        return program.days.reduce(0) { count, day in
            day.isRestDay ? count : (vm.isCompleted(dayNumber: day.dayNumber) ? count + 1 : count)
        }
    }

    private func blockArcSummary(arc: String, currentBlock: Int, nextBlock: Int) -> String {
        let currentArc = arcLabel(for: currentBlock)
        switch currentArc {
        case "accumulation":
            return "Block \(currentBlock) was about laying volume — base reps, base shape. Block \(nextBlock) shifts into \(arc): heavier loads, lower reps, harder finishes."
        case "intensification":
            return "Block \(currentBlock) pushed intensity. Block \(nextBlock) moves into \(arc): peak weights, sharpest output, the highest output of the cycle."
        case "realization":
            return "Block \(currentBlock) was peak. Block \(nextBlock) resets into \(arc): rebuild volume, set the next ceiling."
        default:
            return "Block \(currentBlock) is in the books. Block \(nextBlock) shifts into \(arc) — different stimulus, fresh adaptations."
        }
    }

    private func blockProgressTeaser(delta: ScanDeltaReport, nextBlock: Int) -> String {
        let improvement = delta.improvements.first?.capitalized
        switch improvement {
        case let improvement?:
            return "\(improvement) trending up. Block \(nextBlock) builds on it."
        case nil:
            return "Tap to see the side-by-side."
        }
    }

    private var noProgramState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "dumbbell")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No program yet")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Complete onboarding to generate your first training block.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func programBody(_ program: TrainingProgram) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            // AnyView-wrap the heavy section builders. Inlined, their combined
            // `some View` generic type is deep enough that the Swift runtime
            // overflows the stack instantiating its metadata on device
            // (EXC_BAD_ACCESS in SubstGenericParametersFromMetadata on the
            // Program tab; the simulator's larger budget hid it). Each AnyView
            // caps that subtree's metadata depth. Do NOT "simplify" these back to
            // bare calls — the crash returns.
            VStack(alignment: .leading, spacing: 16) {
                #if DEBUG
                AnyView(devDaySimulatorCard)
                #endif
                AnyView(savedWorkoutsEntryCard)
                AnyView(weekStrip(program: program))
                AnyView(dayCard(program: program))
                AnyView(programFocusCard(program))
                if let proposal = rolloverProposal, proposal.scanDeltaReport != nil {
                    AnyView(midBlockRescanProposalCard(proposal))
                }
                if !ProgramScheduler.shared.todaysSkillSessions(on: programToday).isEmpty {
                    AnyView(todaysTrainingSection)
                }
                CoachActionsRow(
                    program: program,
                    todayDay: programDay(for: programToday, in: program)
                )
                .environmentObject(services)
                AnyView(programHeader(program))
                if !services.entitlement.isEntitled {
                    AnyView(subscriptionBanner)
                }
                Spacer().frame(height: 118)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .fullScreenCover(item: $resumeDraft) { draft in
            ActiveWorkoutContainerView(
                workout: Workout(name: "", targetMuscleGroups: [], warmup: [],
                                mainExercises: [], cooldown: [], estimatedMinutes: 0,
                                notes: nil, blockType: nil),
                programId: "",
                dayNumber: 0,
                services: services,
                resuming: draft
            ) {
                UserDefaults.standard.set(0, forKey: "unbound.shortSessionDate")
                resumeDraft = nil
                Task { await refreshHistory() }
            }
        }
        .task(id: program.id) {
            await loadBlockRolloverContext(program: program)
            viewModel?.refreshWaveAdjustments(asOf: selectedDayDate)
        }
        .task(id: selectedDayDate) {
            viewModel?.refreshWaveAdjustments(asOf: selectedDayDate)
        }
    }

    private func programFocusCard(_ program: TrainingProgram) -> some View {
        let style = effectiveTrainingStyle()
        let isBodyweight = style == .bodyweight
        let equipment = currentEquipmentFallback(program: program)
        let equipmentLabel = equipmentDisplayLabel(equipment)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isBodyweight ? "figure.strengthtraining.functional" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isBodyweight ? Color.unbound.success : Color.unbound.coachCyan)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill((isBodyweight ? Color.unbound.success : Color.unbound.coachCyan).opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("PROGRAM FOCUS")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(isBodyweight ? "Bodyweight focus active" : "Want to switch to calisthenics?")
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(isBodyweight
                         ? "This block is already using bodyweight-first programming. You can still rebuild it as no-equipment or bar-and-band work."
                         : "Start a new bodyweight block today. Completed sessions stay in history; future programming uses your latest logs and standards.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                focusMetaPill(title: style.displayName, icon: "slider.horizontal.3")
                focusMetaPill(title: equipmentLabel, icon: "wrench.and.screwdriver")
            }

            Button {
                UnboundHaptics.soft()
                focusSwitchErrorMessage = nil
                focusSwitchPresentation = ProgramFocusSwitchPresentation(
                    currentStyle: style,
                    currentEquipment: equipment,
                    currentExperience: currentProfile?.experience
                )
            } label: {
                HStack(spacing: 8) {
                    if isSwitchingProgramFocus {
                        ProgressView()
                            .tint(Color.unbound.textPrimary)
                            .scaleEffect(0.78)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text(isBodyweight ? "TUNE BODYWEIGHT BLOCK" : "SWITCH FOCUS")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(Color.unbound.coachCyan.opacity(0.2))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.unbound.coachCyan.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSwitchingProgramFocus)
            .accessibilityIdentifier("program.focusSwitch")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(0.25), lineWidth: 1)
        )
    }

    private func focusMetaPill(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title.uppercased())
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(Color.unbound.textSecondary)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(Color.unbound.bg.opacity(0.7))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func effectiveTrainingStyle() -> TrainingStyle {
        if let override = currentProfile?.trainingStyleOverride {
            return override
        }
        let equipment = currentProfile?.equipment ?? []
        let styles = Set(currentProfile?.exerciseStyles ?? [])
        let bodyweightGear: Set<Equipment> = [.bodyweight, .pullupBar, .bands, .dipStation, .rings]
        let selectedEquipment = Set(equipment)
        let wantsCalisthenics = styles.contains(.calisthenics)
        let wantsMachines = styles.contains(.machines) || equipment.contains(.machines)
        let wantsFreeWeights = styles.contains(.compoundLifts)
            || equipment.contains(.barbell)
            || equipment.contains(.dumbbells)
            || equipment.contains(.bench)

        if wantsCalisthenics && (wantsFreeWeights || wantsMachines) {
            return .hybrid
        }
        if wantsCalisthenics || (!selectedEquipment.isEmpty && selectedEquipment.isSubset(of: bodyweightGear)) {
            return .bodyweight
        }
        if wantsMachines && wantsFreeWeights {
            return .hybrid
        }
        if wantsMachines {
            return .machines
        }
        if wantsFreeWeights {
            return .freeWeights
        }
        return .hybrid
    }

    private func currentEquipmentFallback(program: TrainingProgram) -> [Equipment] {
        if let equipment = currentProfile?.equipment, !equipment.isEmpty {
            return equipment
        }
        let resolved = program.requiredEquipment.compactMap { Equipment(rawValue: $0) }
        return resolved.isEmpty ? [.bodyweight] : resolved
    }

    private func equipmentDisplayLabel(_ equipment: [Equipment]) -> String {
        if equipment.contains(.fullGym) { return "Full gym" }
        if equipment == [.bodyweight] { return "Bodyweight only" }
        let labels = equipment
            .sorted { $0.rawValue < $1.rawValue }
            .prefix(2)
            .map(\.displayName)
        if labels.isEmpty { return "Equipment open" }
        let suffix = equipment.count > 2 ? " +" : ""
        return labels.joined(separator: " / ") + suffix
    }

    @MainActor
    private func applyFocusSwitch(_ selection: ProgramFocusSwitchSelection) async {
        guard !isSwitchingProgramFocus else { return }
        guard let viewModel else {
            focusSwitchErrorMessage = "Program is still loading. Try again in a moment."
            return
        }
        guard let userId = services.auth.currentUserId else {
            focusSwitchErrorMessage = "Sign in again before changing the active block."
            return
        }

        isSwitchingProgramFocus = true
        focusSwitchErrorMessage = nil
        do {
            let profile = try await focusSwitchProfile(userId: userId)
            let updatedStyles = selection.updatedExerciseStyles(from: Set(profile.exerciseStyles ?? []))
            let generated = try await viewModel.switchProgramFocus(
                profile: profile,
                trainingStyle: selection.trainingStyle,
                equipment: selection.equipment,
                exerciseStyles: updatedStyles,
                experience: selection.abilityLevel.experience
            )

            var updatedProfile = profile
            updatedProfile.currentProgramId = generated.id
            updatedProfile.trainingStyleOverride = selection.trainingStyle
            updatedProfile.equipment = selection.sortedEquipment
            updatedProfile.exerciseStyles = updatedStyles.sorted { $0.rawValue < $1.rawValue }
            updatedProfile.experience = selection.abilityLevel.experience
            currentProfile = updatedProfile

            selectedDayDate = programToday
            weekOffset = 0
            focusSwitchPresentation = nil
            UnboundHaptics.success()
            await refreshHistory()
        } catch {
            focusSwitchErrorMessage = "Could not rebuild the block. Check your connection and try again."
            LoggingService.shared.log(
                "Program focus switch failed: \(error)",
                level: .error,
                context: [
                    "equipment": selection.sortedEquipment.map(\.rawValue).joined(separator: ","),
                    "ability": selection.abilityLevel.rawValue
                ]
            )
        }
        isSwitchingProgramFocus = false
    }

    @MainActor
    private func focusSwitchProfile(userId: String) async throws -> UserProfile {
        if let currentProfile { return currentProfile }
        let profile = try await services.user.fetchProfile(userId: userId)
        currentProfile = profile
        return profile
    }

    private func midBlockRescanProposalCard(_ proposal: BlockRolloverService.ProgramBlockProposal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                Text("NEXT BLOCK INPUT")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                Text("BLOCK \(proposal.nextBlockNumber)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Text(proposal.midBlockPatchPolicy.detail)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(proposal.lines.prefix(3).enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: proposalIcon(for: line.kind))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(proposalColor(for: line.kind))
                            .frame(width: 16)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.title)
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(2)
                            Text(line.detail)
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Button {
                UnboundHaptics.soft()
                showCheckpointFlow = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 11, weight: .bold))
                    Text("CHECKPOINT")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                    Spacer()
                    Text("optional")
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(
                    Capsule()
                        .fill(Color.unbound.accent.opacity(0.16))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.26), lineWidth: 1)
        )
    }

    private func programHeader(_ program: TrainingProgram) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("\(program.durationDays) DAYS")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
        }
    }

    // MARK: - Week strip

    private var weekStart: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: programToday)
        let base = cal.date(from: comps) ?? programToday
        return cal.date(byAdding: .day, value: weekOffset * 7, to: base) ?? base
    }

    private func weekDates() -> [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func weekStrip(program: TrainingProgram) -> some View {
        let dates = weekDates()
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { shift(weeks: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(weekRangeLabel(from: dates.first ?? Date(), to: dates.last ?? Date()))
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)

                Spacer()

                Button { shift(weeks: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                ForEach(dates, id: \.self) { date in
                    dayTile(date: date, program: program)
                }
            }
        }
    }

    private func shift(weeks: Int) {
        UnboundHaptics.soft()
        withAnimation(.easeInOut(duration: 0.18)) {
            weekOffset += weeks
        }
    }

    private func dayTile(date: Date, program: TrainingProgram) -> some View {
        let cal = Calendar.current
        let isToday = isProgramToday(date)
        let isSelected = cal.isDate(selectedDayDate, inSameDayAs: date)
        let isPast = isProgramPast(date)

        let day = programDay(for: date, in: program)
        let status = tileStatus(isToday: isToday, isPast: isPast, day: day, program: program)

        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let weekday = ((cal.component(.weekday, from: date) + 5) % 7)
        let dayNum = cal.component(.day, from: date)

        return Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDayDate = cal.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 6) {
                Text(letters[weekday])
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(isToday ? Color.unbound.accent : Color.unbound.textTertiary)
                Text("\(dayNum)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(
                        isToday || isSelected
                            ? Color.unbound.textPrimary
                            : Color.unbound.textSecondary
                    )
                    .monospacedDigit()
                tileStatusGlyph(status: status)
                    .frame(height: 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.unbound.accent.opacity(0.16)
                            : Color.unbound.surface
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isToday
                            ? Color.unbound.accent.opacity(0.75)
                            : Color.unbound.borderSubtle,
                        lineWidth: isToday ? 1.2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private enum TileStatus { case completed, today, rest, planned, locked }

    private func tileStatus(isToday: Bool, isPast: Bool, day: ProgramDay?, program: TrainingProgram) -> TileStatus {
        if let day, day.isRestDay { return .rest }
        if let day, let vm = viewModel, vm.isCompleted(dayNumber: day.dayNumber) { return .completed }
        if isToday { return .today }
        if isPast { return .locked }
        return .planned
    }

    @ViewBuilder
    private func tileStatusGlyph(status: TileStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
        case .today:
            Circle()
                .fill(Color.unbound.accent)
                .frame(width: 6, height: 6)
                .shadow(color: Color.unbound.accent.opacity(0.65), radius: 3)
        case .rest:
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.unbound.textTertiary)
        case .planned:
            Circle()
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                .frame(width: 6, height: 6)
        case .locked:
            Circle()
                .fill(Color.unbound.borderSubtle)
                .frame(width: 4, height: 4)
        }
    }

    // MARK: - Day card

    private func dayCard(program: TrainingProgram) -> some View {
        let day = programDay(for: selectedDayDate, in: program)
        let cal = Calendar.current
        let isToday = isProgramToday(selectedDayDate)
        let isPast = isProgramPast(selectedDayDate)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(commandHeaderLabel(for: day, date: selectedDayDate, isToday: isToday))
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(isCalibrationDay(day) ? Color.unbound.accent : (isToday ? Color.unbound.coachCyan : Color.unbound.textTertiary))
                    Text(cardTitle(for: day))
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                    Text(longDateLabel(for: selectedDayDate).uppercased())
                        .font(Font.unbound.monoS)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer(minLength: 10)
                dayStatusBadge(day: day, isToday: isToday, isPast: isPast)
            }

            HStack(spacing: 8) {
                todayStatPill(value: exerciseCountLabel(for: day), label: "EXERCISES")
                todayStatPill(value: durationLabel(for: day), label: "TIME")
                todayStatPill(
                    value: isCalibrationDay(day) ? "6-7" : (day?.isRestDay == true ? "REC" : "LIVE"),
                    label: isCalibrationDay(day) ? "RPE" : (day?.isRestDay == true ? "MODE" : "READY")
                )
            }

            if let day {
                ProgramFuelTargetBand(plan: program.nutritionPlan, day: day)
            }

            if let day, !day.isRestDay, let workout = day.workout {
                workoutVisualPreview(workout: workout)
                modifierSummary(for: day, workout: workout)
                waveAdjustmentPanel(for: day)
                exerciseList(workout: workout)
            }

            HStack(spacing: 10) {
                Button {
                    UnboundHaptics.medium()
                    if !services.entitlement.isEntitled {
                        showPaywall = true
                        return
                    }
                    if let day {
                        if isToday, day.isRestDay {
                            Task { await completeRecoveryDay(day) }
                        } else if isToday, !day.isRestDay, day.workout != nil {
                            if let draft = resumableDraft(for: day) {
                                resumeDraft = draft
                            } else {
                                launchActiveWorkout(for: day, date: selectedDayDate)
                            }
                        } else {
                            selectedDay = day
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(ctaLabel(for: day, isToday: isToday))
                            .font(Font.unbound.bodyMStrong)
                            .tracking(1.6)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .allowsTightening(true)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.accent)
                    )
                    .shadow(color: Color.unbound.accent.opacity(0.35), radius: 10, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(day == nil || isCompletingRecoveryDay)
                .accessibilityIdentifier("program.startSession")

                if let day, isToday, !day.isRestDay, day.workout != nil {
                    Button {
                        UnboundHaptics.soft()
                        if !services.entitlement.isEntitled {
                            showPaywall = true
                            return
                        }
                        launchSessionEditor(for: day, date: selectedDayDate)
                    } label: {
                        Text("EDIT")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(width: 74, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.unbound.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("program.editSession")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.coachCyan.opacity(isToday ? 0.18 : 0.06),
                                Color.unbound.accent.opacity(isToday ? 0.12 : 0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack {
                    Rectangle()
                        .fill(Color.unbound.coachCyan.opacity(isToday ? 0.86 : 0.2))
                        .frame(height: 3)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(isToday ? 0.42 : 0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func dayStatusBadge(day: ProgramDay?, isToday: Bool, isPast: Bool) -> some View {
        if isPast, let d = day, viewModel?.isCompleted(dayNumber: d.dayNumber) == true {
            statusBadge("DONE", icon: "checkmark", tint: Color.unbound.success)
        } else if day?.isRestDay == true {
            statusBadge("REST", icon: "moon.zzz.fill", tint: Color.unbound.textSecondary)
        } else if isCalibrationDay(day) {
            statusBadge("CAL", icon: "target", tint: Color.unbound.accent)
        } else if isToday {
            statusBadge("START", icon: "bolt.fill", tint: Color.unbound.coachCyan)
        } else {
            statusBadge("PLAN", icon: "calendar", tint: Color.unbound.textSecondary)
        }
    }

    private func statusBadge(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(tint.opacity(0.13)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
    }

    private func todayStatPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Font.unbound.monoM.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(0.9)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func exerciseCountLabel(for day: ProgramDay?) -> String {
        guard let day, !day.isRestDay, let workout = day.workout else { return "0" }
        return "\(workout.mainExercises.count)"
    }

    private func durationLabel(for day: ProgramDay?) -> String {
        guard let day, !day.isRestDay, let workout = day.workout else { return "REC" }
        return "~\(workout.estimatedMinutes)M"
    }

    @ViewBuilder
    private func modifierSummary(for day: ProgramDay, workout: Workout) -> some View {
        let summary = programModifierSummary(for: day, workout: workout)
        if !summary.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("WHY THIS SESSION CHANGED")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
                ForEach(Array(summary.visibleLines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: line.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color(for: line.colorRole))
                            .padding(.top, 2)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.title)
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(0.6)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(1)
                            Text(line.detail)
                                .font(Font.unbound.captionS)
                                .tracking(0.3)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                }
                if summary.overflowCount > 0 {
                    Text("+\(summary.overflowCount) more modifier\(summary.overflowCount == 1 ? "" : "s")")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.leading, 22)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func programModifierSummary(for day: ProgramDay, workout: Workout) -> ProgramModifierSummary {
        guard let draft = programDraft(from: workout, day: day, date: selectedDayDate) else {
            return ProgramModifierSummary(lines: [], visibleLimit: 3)
        }
        return ProgramModifierSummary.summarize(
            draft: draft,
            isTravelDay: activeTravelOverride?.day(for: selectedDayDate) != nil
        )
    }

    @ViewBuilder
    private func waveAdjustmentPanel(for day: ProgramDay) -> some View {
        let adjustments = waveAdjustments(for: day)
        if !adjustments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("WAVE 2 ADJUSTMENTS")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
                ForEach(adjustments) { adjustment in
                    waveAdjustmentRow(adjustment)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.28), lineWidth: 1)
            )
        }
    }

    private func waveAdjustmentRow(_ adjustment: WaveAdjustment) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: adjustment.reason.iconSystemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
                .padding(.top, 2)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(adjustment.reason.decisionApplied)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                Text(adjustment.reason.inputSummary)
                    .font(Font.unbound.captionS)
                    .tracking(0.2)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            if adjustment.reason.revertible {
                Button {
                    UnboundHaptics.soft()
                    viewModel?.revertWaveAdjustment(adjustment, asOf: selectedDayDate)
                } label: {
                    Text("UNDO")
                        .font(Font.unbound.captionS.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(Color.unbound.warnOrange)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(Capsule().fill(Color.unbound.warnOrange.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(Color.unbound.warnOrange.opacity(0.28), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("program.waveAdjustment.undo.\(adjustment.dayNumber)")
            }
        }
    }

    private func waveAdjustments(for day: ProgramDay) -> [WaveAdjustment] {
        viewModel?.activeWaveAdjustments.filter { $0.dayNumber == day.dayNumber } ?? []
    }

    private func color(for role: ProgramModifierColorRole) -> Color {
        switch role {
        case .accent:
            return Color.unbound.accent
        case .warning:
            return Color.unbound.warnOrange
        case .neutral:
            return Color.unbound.textSecondary
        }
    }

    private func workoutVisualPreview(workout: Workout) -> some View {
        let primary = workout.mainExercises.first
        let primaryDefinition = primary.flatMap { movementDefinition(for: $0) }

        return HStack(alignment: .center, spacing: 12) {
            workoutExerciseVisual(definition: primaryDefinition, size: .hero)
                .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 9) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WORKOUT")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.coachCyan)
                    Text(primary?.name.uppercased() ?? workout.name.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.3)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                HStack(spacing: 8) {
                    todayStatPill(value: "\(workout.mainExercises.count)", label: "MOVES")
                    todayStatPill(value: durationLabel(for: workout), label: "TIME")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func exerciseList(workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(workout.mainExercises.prefix(5).enumerated()), id: \.offset) { index, ex in
                visualExerciseRow(ex, isLastVisible: index == min(workout.mainExercises.count, 5) - 1)
            }
            if workout.mainExercises.count > 5 {
                Text("+\(workout.mainExercises.count - 5) more")
                    .font(Font.unbound.captionS)
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.top, 8)
                    .padding(.leading, 2)
            }
        }
        .padding(.vertical, 2)
    }

    private func visualExerciseRow(_ exercise: Exercise, isLastVisible: Bool) -> some View {
        HStack(spacing: 10) {
            workoutExerciseVisual(definition: movementDefinition(for: exercise), size: .thumbnail)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name.uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(exercise.muscleGroups.prefix(2).map(\.displayName).joined(separator: " / ").uppercased())
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            Text("\(exercise.sets)×\(exercise.reps)")
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if !isLastVisible {
                Rectangle()
                    .fill(Color.unbound.borderSubtle.opacity(0.72))
                    .frame(height: 1)
                    .padding(.leading, 56)
            }
        }
    }

    @ViewBuilder
    private func workoutExerciseVisual(
        definition: MovementDefinition?,
        size: ExerciseVisualView.Size
    ) -> some View {
        if let definition {
            ExerciseVisualView(definition: definition, size: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: size.iconSize * 0.65, weight: .semibold))
                    .foregroundStyle(Color.unbound.coachCyan)
            }
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func movementDefinition(for exercise: Exercise) -> MovementDefinition? {
        MovementCatalog.canonicalExercise(named: exercise.name)
    }

    private func durationLabel(for workout: Workout) -> String {
        "~\(workout.estimatedMinutes)M"
    }

    // MARK: - ROUTINES tab

    private var routinesTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Pick a side mission when the main plan is not the move. Rewards come from the work you log.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                challengeLibrary

                ForEach(RoutineCategory.allCases.filter { $0 != .challenge }, id: \.self) { cat in
                    routineSection(category: cat)
                }

                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var challengeLibrary: some View {
        let challenges = RoutineLibrary.routines(category: .challenge)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: RoutineCategory.challenge.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RoutineCategory.challenge.color)
                Text("CHALLENGE LIBRARY")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(RoutineCategory.challenge.color)
                Spacer()
                Text("\(challenges.count) missions")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            TabView(selection: $selectedChallengeId) {
                ForEach(challenges) { routine in
                    Button {
                        beginRoutineTravel(routine)
                    } label: {
                        RoutineChallengeCard(routine: routine)
                    }
                    .buttonStyle(RoutineChallengePressStyle())
                    .tag(routine.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 356)

            RoutineChallengeDots(challenges: challenges, selectedId: selectedChallengeId)
        }
    }

    private func beginRoutineTravel(_ routine: RoutineDef) {
        UnboundHaptics.medium()
        travelingRoutine = routine
        routineTravelProgress = 0
        withAnimation(.easeInOut(duration: 0.58)) {
            routineTravelProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            activeRoutinePlayer = routine
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.easeOut(duration: 0.18)) {
                travelingRoutine = nil
                routineTravelProgress = 0
            }
        }
    }

    #if DEBUG
    private func openRoutineForProofIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--unbound-open-routine"),
              !debugOpenedRoutine
        else { return }

        debugOpenedRoutine = true
        selectedTab = .routines

        let requestedId = Self.launchArgumentValue(for: "--unbound-open-routine")
        let routine = requestedId
            .flatMap { id in RoutineLibrary.placeholderRoutines.first { $0.id == id } }
            ?? RoutineLibrary.routines(category: .challenge).first
            ?? RoutineLibrary.routinesSortedByDifficulty.first

        guard let routine else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            beginRoutineTravel(routine)
        }
    }

    private static func launchArgumentValue(for key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        for (index, argument) in arguments.enumerated() {
            if argument == key, arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
            if argument.hasPrefix("\(key)=") {
                return String(argument.dropFirst(key.count + 1))
            }
        }
        return nil
    }
    #endif

    private func routineSection(category: RoutineCategory) -> some View {
        let items = RoutineLibrary.routines(category: category)
        let selection = Binding<String>(
            get: { selectedRoutineIdsByCategory[category] ?? items.first?.id ?? "" },
            set: { selectedRoutineIdsByCategory[category] = $0 }
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(category.color)
                Text(category.label)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(category.color)
                Spacer()
                Text("\(items.count) missions")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            TabView(selection: selection) {
                ForEach(items) { routine in
                    Button {
                        beginRoutineTravel(routine)
                    } label: {
                        RoutineChallengeCard(routine: routine)
                    }
                    .buttonStyle(RoutineChallengePressStyle())
                    .tag(routine.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 356)

            RoutineChallengeDots(challenges: items, selectedId: selection.wrappedValue)
        }
    }

    private func routineCard(routine: RoutineDef) -> some View {
        Button {
            UnboundHaptics.medium()
            selectedRoutine = routine
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.title.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(routine.durationLabel)
                        .font(Font.unbound.monoS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Text("PROOF-GATED XP")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(routine.category.color)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(routine.category.color.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func refreshHistory() async {
        guard let userId = services.auth.currentUserId else { return }
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 40)) ?? []
        pastLogs = logs.filter { $0.completedAt != nil }
    }

    @MainActor
    private func refreshTravelOverride() async {
        guard let userId = services.auth.currentUserId else { return }
        activeTravelOverride = await TravelOverrideStore.shared.activeOverride(for: userId)
    }

    @MainActor
    private func applyCheckpointOutcome(_ outcome: CheckpointOutcome) async {
        await viewModel?.completeCheckpoint(outcome)
        if let program = viewModel?.program {
            await loadBlockRolloverContext(program: program)
        }
    }

    private var checkpointNutritionContext: NutritionContext {
        let hardSessionWithin24Hours = pastLogs.contains { log in
            guard let completedAt = log.completedAt else { return false }
            return programNow.timeIntervalSince(completedAt) <= 86_400
        }
        return NutritionTargetCalculator().calculate(
            input: NutritionTargetCalculator.Input(
                bodyweightKilograms: currentProfile?.weightKg,
                hardSessionLoggedWithin24Hours: hardSessionWithin24Hours
            )
        )
    }

    private var checkpointMissedSessionSignal: MissedSessionSignal {
        guard let program = viewModel?.program else { return .onTrack }
        let now = programNow
        let sessions = scheduledAttendance(for: program, now: now)
        let result = MissedSessionMetric.evaluate(sessions: sessions, now: now)
        return MissedSessionSignal.fromScheduledSessions(
            scheduled: result.scheduledCount,
            missed: result.missedCount
        )
    }

    private func scheduledAttendance(
        for program: TrainingProgram,
        now: Date
    ) -> [ScheduledSessionAttendance] {
        let calendar = Calendar.current
        return program.days.compactMap { day in
            guard !day.isRestDay else { return nil }
            guard let scheduledAt = calendar.date(
                byAdding: .day,
                value: day.dayNumber - 1,
                to: calendar.startOfDay(for: BlockRolloverScheduler.activeStartDate(for: program))
            ) else {
                return nil
            }
            guard scheduledAt <= now else { return nil }
            let completedAt = viewModel?.workoutLogs[day.dayNumber]?.completedAt
                ?? viewModel?.workoutLogs[day.dayNumber]?.startedAt
            return ScheduledSessionAttendance(
                scheduledAt: scheduledAt,
                completedAt: completedAt
            )
        }
    }

    // MARK: - Helpers

    private func programDay(for date: Date, in program: TrainingProgram) -> ProgramDay? {
        // Travel override wins whenever today falls in its window — the
        // normal program rotation is suspended until the user is back.
        if let override = activeTravelOverride, let tday = override.day(for: date) {
            return travelProgramDay(from: tday, on: date)
        }
        guard !program.days.isEmpty else { return nil }
        let anchorDate = BlockRolloverScheduler.activeStartDate(for: program)
        let daysSinceStart = Calendar.current.dateComponents(
            [.day], from: anchorDate, to: date
        ).day ?? 0
        let idx = ((daysSinceStart % program.days.count) + program.days.count) % program.days.count
        return program.days[idx]
    }

    private func currentProgramDayNumber(in program: TrainingProgram) -> Int? {
        guard !program.days.isEmpty else { return nil }
        let anchorDate = BlockRolloverScheduler.activeStartDate(for: program)
        let daysSinceStart = Calendar.current.dateComponents(
            [.day], from: anchorDate, to: programToday
        ).day ?? 0
        let idx = ((daysSinceStart % program.days.count) + program.days.count) % program.days.count
        return program.days[idx].dayNumber
    }

    /// Synthesize a ProgramDay from a travel override day so the rest of
    /// the UI renders it like any other scheduled workout.
    private func travelProgramDay(from tday: TravelDay, on date: Date) -> ProgramDay {
        let workout = tday.workout(summary: "Travel plan: \(activeTravelOverride?.summary ?? "Keep rhythm without rewriting the main arc.")")
        return ProgramDay(
            id: "travel-\(Int(date.timeIntervalSince1970))",
            dayNumber: 0,
            label: tday.isRest ? "TRAVEL · REST" : "TRAVEL · \(tday.title)",
            isRestDay: tday.isRest,
            workout: workout,
            nutritionOverride: nil,
            recoveryActivities: []
        )
    }

    /// Parse the duration string ("~30 MIN", "45 min", etc.) into
    /// an integer minute count; falls back to 30 if parsing fails.
    private func parseMinutes(from text: String) -> Int {
        let digits = text.compactMap { $0.isNumber ? $0 : nil }
        if let n = Int(String(digits)), n > 0 { return n }
        return 30
    }

    private func cardTitle(for day: ProgramDay?) -> String {
        guard let day else { return "NO SESSION" }
        if day.isRestDay { return "REST DAY" }
        return day.workout?.name.uppercased() ?? "NO SESSION"
    }

    private func cardSubtitle(for day: ProgramDay?) -> String {
        guard let day else { return "Plan your next move." }
        if day.isRestDay { return "Recovery is the work." }
        if let workout = day.workout {
            return "\(workout.mainExercises.count) EXERCISES · ~\(workout.estimatedMinutes)M"
        }
        return "Plan your next move."
    }

    private func ctaLabel(for day: ProgramDay?, isToday: Bool) -> String {
        guard let day else { return "NOTHING PLANNED" }
        if day.isRestDay { return isToday ? "COMPLETE RECOVERY" : "VIEW RECOVERY" }
        if isCalibrationDay(day) { return "LOCK STANDARD" }
        if isToday, resumableDraft(for: day) != nil { return "RESUME SESSION" }
        if isToday { return "BEGIN SESSION" }
        return "VIEW DETAILS"
    }

    private func resumableDraft(for day: ProgramDay?) -> ActiveWorkoutSession? {
        guard let day,
              let program = viewModel?.program,
              day.workout != nil,
              draftStore.hasDraft
        else { return nil }

        guard let draft = draftStore.load() else { return nil }

        guard draft.programId == program.id,
              draft.dayNumber == day.dayNumber,
              !draft.exercises.isEmpty
        else { return nil }

        return draft
    }

    private func commandHeaderLabel(for day: ProgramDay?, date: Date, isToday: Bool) -> String {
        if isCalibrationDay(day) {
            return isToday ? "CALIBRATION COMMAND" : "CALIBRATION"
        }
        return isToday ? "TODAY COMMAND" : dayHeaderLabel(for: date).uppercased()
    }

    private func isCalibrationDay(_ day: ProgramDay?) -> Bool {
        guard let day, !day.isRestDay else { return false }
        if day.label.localizedCaseInsensitiveContains("Calibration") { return true }
        return day.workout?.notes?.localizedCaseInsensitiveContains("Calibration:") == true
    }

    private func weekRangeLabel(from: Date, to: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: from).uppercased()) — \(f.string(from: to).uppercased())"
    }

    private func dayHeaderLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func longDateLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date)
    }

    // MARK: - Legacy subviews

    private var subscriptionBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.unbound.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock your full program")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Subscribe to access workouts, nutrition & recovery.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func errorState(_ error: Error?) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.unbound.alert)
            Text(error?.localizedDescription ?? "Program unavailable.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                Task { await loadProgramSurface() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(Font.unbound.bodyS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(
                        Capsule()
                            .fill(Color.unbound.accent.opacity(0.22))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("program.retry")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Routine step preview helper

private func routineStepPreview(_ step: RoutineStep) -> String {
    switch step {
    case .instruction(let t, _):            return t
    case .timed(let l, let s, _):           return "\(l) — \(s)s"
    case .interval(let l, let r, _):        return "\(l) — \(r) rounds"
    case .repTarget(let n, let t, _):       return t.map { "\(n) — \($0)" } ?? "\(n) — AMRAP"
    case .circuit(let r, _, let steps):
        let moves = steps.compactMap(routineStepShortLabel).prefix(4).joined(separator: " + ")
        return moves.isEmpty ? "Circuit × \(r) rounds" : "Circuit × \(r): \(moves)"
    case .note(let t):                      return t
    }
}

private func routineStepShortLabel(_ step: RoutineStep) -> String? {
    switch step {
    case .instruction(let text, _):
        return text.components(separatedBy: "—").first?
            .components(separatedBy: "×").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    case .timed(let label, _, let style):
        return style == .work ? label : nil
    case .repTarget(let name, _, _):
        return name
    case .interval(let label, _, _):
        return label
    case .circuit, .note:
        return nil
    }
}

// MARK: - Routine challenge carousel

private struct RoutineDifficultyBadge: View {
    let tier: SkillTier
    var compact: Bool = false

    private var tint: Color { tier.rewardTextTint }

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            Image(tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 14 : 18, height: compact ? 14 : 18)

            Text(tier.displayName.uppercased())
                .font(compact ? Font.unbound.monoS.weight(.heavy) : Font.unbound.captionS.weight(.heavy))
                .tracking(compact ? 1.0 : 1.3)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, compact ? 9 : 11)
        .padding(.vertical, compact ? 6 : 8)
        .background(Capsule().fill(Color.unbound.bg.opacity(compact ? 0.62 : 0.52)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.36), lineWidth: 1))
        .accessibilityLabel("\(tier.displayName) routine difficulty")
    }
}

private struct RoutineChallengeCard: View {
    let routine: RoutineDef

    private var canComplete: Bool {
        RoutineHistoryStore.shared.canComplete(routineId: routine.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                routineCover
                    .frame(height: 198)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                LinearGradient(
                    colors: [.clear, Color.unbound.bg.opacity(0.70), Color.unbound.bg.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    statusChip
                    Text(routine.title.uppercased())
                        .font(Font.unbound.titleL)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                    Text(routine.subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
                .padding(18)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    metricPill(value: routine.durationLabel, label: "TIME")
                    rankMetricPill(tier: routine.difficultyTier)
                    metricPill(value: "PROOF", label: "LVL XP")
                }

                HStack(spacing: 12) {
                    Text(routine.steps.first.map(routineStepPreview) ?? "Open the mission and start.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Text(canComplete ? "READY" : "OPEN")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.4)
                        Image(systemName: canComplete ? "arrow.right" : "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.bg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(canComplete ? routine.category.color : Color.unbound.textTertiary))
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(routine.category.color.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: routine.category.color.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var routineCover: some View {
        if let image = UIImage(named: routine.coverAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .saturation(canComplete ? 1 : 0.25)
                .opacity(canComplete ? 0.9 : 0.48)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        routine.category.color.opacity(0.46),
                        Color.unbound.emberDeep.opacity(0.34),
                        Color.unbound.bg
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Path { path in
                    path.move(to: CGPoint(x: 24, y: 146))
                    path.addCurve(
                        to: CGPoint(x: 190, y: 44),
                        control1: CGPoint(x: 78, y: 92),
                        control2: CGPoint(x: 114, y: 34)
                    )
                    path.addCurve(
                        to: CGPoint(x: 335, y: 118),
                        control1: CGPoint(x: 252, y: 54),
                        control2: CGPoint(x: 262, y: 146)
                    )
                }
                .stroke(
                    routine.category.color.opacity(0.72),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: routine.category.color.opacity(0.30), radius: 10)

                Image(systemName: routine.category.systemImage)
                    .font(.system(size: 118, weight: .black))
                    .foregroundStyle(routine.category.color.opacity(0.18))
                    .offset(x: 90, y: -34)
            }
        }
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(canComplete ? routine.category.color : Color.unbound.textTertiary)
                .frame(width: 6, height: 6)
            Text(canComplete ? "MISSION READY" : "CLEARED TODAY")
                .font(Font.unbound.monoS.weight(.heavy))
                .tracking(1.3)
        }
        .foregroundStyle(canComplete ? routine.category.color : Color.unbound.textTertiary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.unbound.bg.opacity(0.62)))
        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }

    private func metricPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
    }

    private func rankMetricPill(tier: SkillTier) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(tier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)

                Text(tier.displayName.uppercased())
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            Text("RANK")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tier.rewardTextTint.opacity(0.24), lineWidth: 1)
        )
        .accessibilityLabel("\(tier.displayName) routine rank")
    }
}

private struct RoutineChallengeDots: View {
    let challenges: [RoutineDef]
    let selectedId: String

    var body: some View {
        HStack(spacing: 9) {
            ForEach(challenges) { routine in
                Capsule()
                    .fill(routine.id == selectedId ? routine.category.color : Color.unbound.textTertiary.opacity(0.32))
                    .frame(width: routine.id == selectedId ? 24 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: selectedId)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 20)
    }
}

private struct RoutineTravelOverlay: View {
    let routine: RoutineDef
    let progress: CGFloat

    var body: some View {
        ZStack {
            Color.unbound.bg.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(routine.category.color.opacity(0.16), lineWidth: 18)
                        .frame(width: 166, height: 166)
                        .scaleEffect(1 + progress * 0.45)
                        .opacity(Double(1 - progress * 0.55))
                    Image(systemName: routine.category.systemImage)
                        .font(.system(size: 54, weight: .black))
                        .foregroundStyle(routine.category.color)
                        .offset(x: progress * 22, y: -progress * 18)
                        .scaleEffect(1 + progress * 0.12)
                }

                Text("ENTERING MISSION")
                    .font(Font.unbound.monoS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(routine.category.color)
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct RoutineChallengePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private extension RoutineDef {
    var coverAssetName: String { "routine_challenge_\(id)" }
}

private struct RoutineCompletionFlow: View {
    let routine: RoutineDef
    let onFinished: () -> Void

    @EnvironmentObject private var services: ServiceContainer
    @State private var hasStarted = false
    @State private var rewardSequence: WorkoutRewardSequenceSummary?
    @State private var isCompleting = false

    var body: some View {
        ZStack {
            if hasStarted {
                RoutinePlayerView(routine: routine) { record in
                    beginCompletion(record)
                }
                .environmentObject(services)
                .opacity(rewardSequence == nil ? 1 : 0)
                .allowsHitTesting(rewardSequence == nil && !isCompleting)
                .transition(.opacity)
            } else {
                RoutineReadyFace(
                    routine: routine,
                    onClose: {
                        UnboundHaptics.soft()
                        onFinished()
                    },
                    onStart: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            hasStarted = true
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if isCompleting {
                completionOverlay
            }

            if let rewardSequence {
                WorkoutRewardSequenceView(summary: rewardSequence) {
                    UnboundHaptics.medium()
                    onFinished()
                }
                .interactiveDismissDisabled(true)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: rewardSequence != nil)
        .animation(.easeInOut(duration: 0.22), value: hasStarted)
    }

    private var completionOverlay: some View {
        ZStack {
            Color.unbound.bg.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(routine.category.color)
                    .scaleEffect(1.12)
                Text("LOCKING IN")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(routine.category.color)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(routine.category.color.opacity(0.32), lineWidth: 1)
            )
        }
        .accessibilityIdentifier("routine.completing")
    }

    private func beginCompletion(_ record: RoutineCompletionRecord) {
        guard !isCompleting, rewardSequence == nil else { return }
        isCompleting = true
        Task { await complete(record) }
    }

    @MainActor
    private func complete(_ record: RoutineCompletionRecord) async {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Routine completion skipped without authenticated user",
                level: .warning,
                context: ["routineId": routine.id, "recordId": record.id]
            )
            isCompleting = false
            return
        }

        let performanceLog = TrainingSessionAdapters.performanceLogForRoutine(
            routine,
            record: record,
            userId: userId
        )

        let completionResult: TrainingCompletionResult
        do {
            completionResult = try await TrainingCompletionService.shared.complete(
                performanceLog,
                services: services
            )
        } catch {
            LoggingService.shared.log(
                "Routine canonical completion failed: \(error)",
                level: .warning,
                context: ["routineId": routine.id, "recordId": record.id]
            )
            isCompleting = false
            return
        }

        let canClaimRoutineReward = RoutineHistoryStore.shared.canComplete(routineId: routine.id)
        RoutineHistoryStore.shared.record(record)

        if canClaimRoutineReward, completionResult.overallLevelXPGained > 0 {
            RoutineHistoryStore.shared.complete(routine)
        }

        var rewardSummary = RewardSummary()
        rewardSummary.progression = completionResult.progressionReceipt

        UnboundHaptics.success()
        isCompleting = false
        rewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: rewardSummary,
            fallbackXP: 0,
            sourceName: routine.category.label
        )
    }
}

private struct RoutineReadyFace: View {
    let routine: RoutineDef
    let onClose: () -> Void
    let onStart: () -> Void

    private var canEarnLevelXP: Bool {
        RoutineHistoryStore.shared.canComplete(routineId: routine.id)
    }

    private var runCount: Int {
        RoutineRun.build(routine.steps).run.count
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        hero
                        routineStats
                        stepPreview
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 112)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            startDock
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("routine.ready.close")

            Spacer()

            Text("ROUTINE READY")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(routine.category.color)

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let image = UIImage(named: routine.coverAssetName) {
                routineCoverHero(image)
            }

            HStack(spacing: 8) {
                Image(systemName: routine.category.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(routine.category.label.uppercased())
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.5)
                Spacer()
                Text(canEarnLevelXP ? "PROOF-GATED XP" : "PROOF LOGGED")
                    .font(Font.unbound.monoS.weight(.heavy))
                    .foregroundStyle(canEarnLevelXP ? routine.category.color : Color.unbound.textTertiary)
            }
            .foregroundStyle(routine.category.color)

            Text(routine.title.uppercased())
                .font(Font.unbound.displayM)
                .tracking(0.4)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            RoutineDifficultyBadge(tier: routine.difficultyTier)

            Text(routine.subtitle)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(routine.category.color.opacity(0.28), lineWidth: 1)
        )
    }

    private func routineCoverHero(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.unbound.bg.opacity(0.50)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(routine.category.color.opacity(0.22), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private var routineStats: some View {
        HStack(spacing: 8) {
            statPill(value: routine.durationLabel, label: "TIME", icon: "clock")
            statPill(value: routine.difficultyTier.displayName.uppercased(), label: "RANK", icon: "shield.lefthalf.filled")
            statPill(value: "\(runCount)", label: "STEPS", icon: "list.bullet")
            statPill(value: canEarnLevelXP ? "PROOF" : "LOGGED", label: "LVL XP", icon: "sparkles")
        }
    }

    private var stepPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MISSION PLAN")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.7)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(routine.steps.prefix(6).enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(Font.unbound.monoS.weight(.heavy))
                            .foregroundStyle(routine.category.color)
                            .frame(width: 20, alignment: .trailing)
                            .padding(.top, 1)

                        Text(routineStepPreview(step))
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 11)

                    if index < min(routine.steps.count, 6) - 1 {
                        Divider()
                            .background(Color.unbound.borderSubtle)
                            .padding(.leading, 32)
                    }
                }

                if routine.steps.count > 6 {
                    Text("+\(routine.steps.count - 6) more steps")
                        .font(Font.unbound.captionS.weight(.bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.top, 12)
                        .padding(.leading, 32)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
    }

    private var startDock: some View {
        VStack(spacing: 8) {
            Button {
                UnboundHaptics.heavy()
                onStart()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("START ROUTINE")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(routine.category.color)
                )
                .shadow(color: routine.category.color.opacity(0.42), radius: 14, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("routine.ready.start")

            Text(canEarnLevelXP ? "Completion uses the shared rewards screen and actual logged work." : "You can repeat it; only new proof can add LVL XP.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            Color.unbound.bg
                .opacity(0.96)
                .ignoresSafeArea()
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.unbound.borderSubtle)
                .frame(height: 1)
        }
    }

    private func statPill(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(routine.category.color)
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - RoutinePreviewSheet

private struct RoutinePreviewSheet: View {
    let routine: RoutineDef
    @Environment(\.dismiss) private var dismiss
    @State private var didComplete: Bool = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: routine.category.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                            Text(routine.category.label)
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(1.6)
                        }
                        .foregroundStyle(routine.category.color)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(routine.durationLabel)
                                .font(Font.unbound.monoS)
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text("·")
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text("PROOF-GATED XP")
                                .font(Font.unbound.monoM.weight(.bold))
                                .foregroundStyle(routine.category.color)
                        }
                    }

                    if let image = UIImage(named: routine.coverAssetName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 172)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, Color.unbound.bg.opacity(0.55)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(routine.category.color.opacity(0.22), lineWidth: 1)
                            )
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.title.uppercased())
                            .font(Font.unbound.titleL)
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textPrimary)
                        RoutineDifficultyBadge(tier: routine.difficultyTier)
                            .padding(.top, 4)
                        Text(routine.subtitle)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !routine.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("HOW TO DO IT")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(2.0)
                                .foregroundStyle(Color.unbound.textTertiary)
                                .padding(.bottom, 10)

                            ForEach(Array(routine.steps.enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(i + 1)")
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(routine.category.color)
                                        .frame(width: 20, alignment: .trailing)
                                        .padding(.top, 1)
                                    Text(routineStepPreview(step))
                                        .font(Font.unbound.bodyM)
                                        .foregroundStyle(Color.unbound.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 10)
                                if i < routine.steps.count - 1 {
                                    Divider()
                                        .background(Color.unbound.borderSubtle)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.unbound.border, lineWidth: 1)
                        )
                    }

                    let canComplete = RoutineHistoryStore.shared.canComplete(routineId: routine.id)
                    let label: String = {
                        if didComplete { return "PROOF LOGGED" }
                        if !canComplete { return "DONE TODAY · COME BACK TOMORROW" }
                        return "CLOSE PREVIEW"
                    }()
                    let icon: String = {
                        if didComplete || !canComplete { return "checkmark.seal.fill" }
                        return "xmark"
                    }()
                    let isDisabled = didComplete || !canComplete

                    Button {
                        UnboundHaptics.medium()
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Text(label)
                                .font(Font.unbound.bodyMStrong)
                                .tracking(1.6)
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(routine.category.color)
                        )
                        .opacity(isDisabled ? 0.55 : 1.0)
                        .shadow(color: routine.category.color.opacity(0.45), radius: 10, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)

                    Spacer().frame(height: 8)
                }
                .padding(24)
            }
        }
    }
}

// MARK: - DayPreviewSheet (V3)
//
// Modal sheet showing the routed Program Focuses for any day in the 7-day strip.
// Reuses the same launchers as TODAY'S TRAINING — tap card body to open
// SkillDetailView, tap the right-side button to launch the AI session.
// Doesn't filter by canTrain, so the user can preview future-day plans.

private struct DayPreviewSheet: View {
    let date: Date
    let onSelectSkill: (SkillNode) -> Void
    let onTrainSkill: (SkillNode) -> Void

    @Environment(\.dismiss) private var dismiss
    @Bindable private var skillProgress = SkillProgressService.shared

    var body: some View {
        let category = ProgramScheduler.shared.category(for: date)
        let skillIds = ProgramScheduler.shared.skillIds(forDate: date)

        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header(category: category)

                if category == .rest {
                    restEmptyState
                } else if skillIds.isEmpty {
                    noFocusesEmptyState(category: category)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(skillIds, id: \.self) { id in
                                if let node = SkillGraph.shared.node(id: id) {
                                    skillCard(node: node)
                                }
                            }
                        }
                    }
                    Text("Tap a card to view skill details.")
                        .font(Font.unbound.captionS)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func header(category: DayCategory) -> some View {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let weekday = f.string(from: date).uppercased()
        let title = category == .rest
            ? "\(weekday) · REST DAY"
            : "\(weekday) · \(category.displayName.uppercased()) DAY"

        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(longDate(date).uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Color.unbound.surfaceElevated.opacity(0.6))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date)
    }

    private var restEmptyState: some View {
        emptyState(
            icon: "moon.fill",
            title: "Rest day",
            subtitle: "Recover hard. Tomorrow lands harder."
        )
    }

    private func noFocusesEmptyState(category: DayCategory) -> some View {
        emptyState(
            icon: "calendar.badge.clock",
            title: "No focuses routed",
            subtitle: "No Program Focuses match \(category.displayName) day yet. Add one from any skill detail screen."
        )
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text(title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textSecondary)
            Text(subtitle)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    private func skillCard(node: SkillNode) -> some View {
        let asset = SkillTraditionalVisualResolver.assetName(for: node)
        let usesExistingCharacterArt = asset?.hasPrefix("exercise_visual_") == true

        return Button {
            UnboundHaptics.soft()
            onSelectSkill(node)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(usesExistingCharacterArt ? Color.white : Color.unbound.surfaceElevated)
                        .frame(width: 56, height: 56)
                    if let asset, UIImage(named: asset) != nil {
                        Image(asset)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .padding(usesExistingCharacterArt ? 5 : 0)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: node.glyph)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.unbound.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Text("\(node.cluster.displayName) · \(node.placementRank.displayName)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Button {
                    UnboundHaptics.medium()
                    onTrainSkill(node)
                } label: {
                    HStack(spacing: 4) {
                        Text("TRAIN")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.2)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.unbound.accent)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WeeklyScheduleEditorSheet (V4)
//
// V4 changes vs V3:
//   1. Drag-to-reorder via SwiftUI `List` + `.onMove`. Day labels stay
//      pinned (Mon-Sun); the user reorders the CATEGORIES, so dragging
//      Pull from Mon to Sun swaps the categories on those rows. Drag
//      handles stay visible via `.environment(\.editMode, .active)`.
//   2. OPTIMIZE SPLIT — deterministic 7-day split from Program Focuses;
//      populates the draft (no auto-save).
//   3. WEEK PHASE picker — chip + bottom sheet (heavy/moderate/light/
//      deload). Persists immediately via setWeekPhase.
//   4. Tap-a-chip per row still works for picking the category.

private struct WeeklyScheduleEditorSheet: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss
    @Bindable private var skillProgress = SkillProgressService.shared

    /// Local working copy — committed to service on Save.
    @State private var draft: [DayCategory] = []

    /// V4 — deterministic optimize in-flight + error state.
    @State private var isSuggesting: Bool = false
    @State private var suggestErrorVisible: Bool = false

    /// V4 — phase picker sheet.
    @State private var showPhasePicker: Bool = false

    /// V4 — chip-pick sheet for an individual day (replaces the inline
    /// horizontal scroll so the row stays drag-friendly).
    @State private var editingDayIndex: Int? = nil

    private static let dayLabels = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                phaseChipRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                // V4: SwiftUI `List` with `.onMove` so each row gets a
                // drag handle. `.environment(\.editMode, .active)` keeps
                // handles visible without a separate Edit toggle.
                List {
                    Section {
                        ForEach(Array(draft.enumerated()), id: \.offset) { idx, _ in
                            dayRow(index: idx)
                                .listRowBackground(Color.unbound.bg)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        }
                        .onMove(perform: moveCategories)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.unbound.bg)
                .environment(\.editMode, .constant(.active))

                bottomActions
            }
        }
        .onAppear { hydrateDraft() }
        .sheet(isPresented: $showPhasePicker) {
            WeekPhasePickerSheet(
                current: skillProgress.currentWeekPhase,
                onPick: { phase in
                    Task {
                        await SkillProgressService.shared.setWeekPhase(phase)
                        UnboundHaptics.medium()
                    }
                    showPhasePicker = false
                }
            )
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { editingDayIndex.map { DayPickIndex(idx: $0) } },
            set: { editingDayIndex = $0?.idx }
        )) { wrapper in
            DayCategoryPickerSheet(
                dayLabel: Self.dayLabels[wrapper.idx],
                current: draft.indices.contains(wrapper.idx) ? draft[wrapper.idx] : .rest,
                onPick: { cat in
                    if draft.indices.contains(wrapper.idx) {
                        draft[wrapper.idx] = cat
                    }
                    editingDayIndex = nil
                }
            )
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
        }
    }

    // Wrapper because Int isn't Identifiable directly.
    private struct DayPickIndex: Identifiable, Hashable {
        let idx: Int
        var id: Int { idx }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WEEKLY SCHEDULE")
                    .font(Font.unbound.titleS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Drag to reorder. Tap a chip to change.")
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Color.unbound.surfaceElevated.opacity(0.6))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - V4 Phase chip row

    private var phaseChipRow: some View {
        let phase = skillProgress.currentWeekPhase
        return HStack(spacing: 8) {
            Button {
                UnboundHaptics.soft()
                showPhasePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: phase.glyph)
                        .font(.system(size: 10, weight: .bold))
                    Text("\(phase.displayName.uppercased()) WEEK")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Color.unbound.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.unbound.accent.opacity(0.14))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.unbound.accent.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Day row

    private func dayRow(index: Int) -> some View {
        let cat = draft.indices.contains(index) ? draft[index] : .rest

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayLabels[index])
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .frame(width: 96, alignment: .leading)

            Button {
                UnboundHaptics.soft()
                editingDayIndex = index
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: cat.glyph)
                        .font(.system(size: 11, weight: .bold))
                    Text(cat.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.2)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.unbound.accent.opacity(cat == .rest ? 0.10 : 0.85))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            cat == .rest
                                ? Color.unbound.borderSubtle
                                : Color.clear,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    /// Reorder the CATEGORIES while day labels stay pinned. SwiftUI's
    /// `.onMove` already gives us the right semantics — we just apply
    /// it to the categories array.
    private func moveCategories(from source: IndexSet, to destination: Int) {
        UnboundHaptics.soft()
        draft.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        VStack(spacing: 10) {
            UnboundButton(
                title: isSuggesting ? "OPTIMIZING…" : "OPTIMIZE SPLIT",
                variant: .secondary,
                icon: "wand.and.stars.inverse",
                isEnabled: !isSuggesting
            ) {
                Task { await runSuggest() }
            }
            .overlay(alignment: .trailing) {
                if isSuggesting {
                    ProgressView()
                        .tint(Color.unbound.accent)
                        .scaleEffect(0.85)
                        .padding(.trailing, 18)
                }
            }

            if suggestErrorVisible {
                Text("Couldn't optimize. Try again?")
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.alert)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }

            UnboundButton(title: "SAVE", icon: "checkmark") {
                Task { await save() }
            }

            Button {
                UnboundHaptics.soft()
                Task { await resetToDefault() }
            } label: {
                Text("RESET TO DEFAULT")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(
            Color.unbound.bg
                .overlay(
                    Rectangle()
                        .fill(Color.unbound.borderSubtle)
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    // MARK: - Actions

    private func hydrateDraft() {
        // Seed the draft from the user's current effective schedule
        // so the picker shows what's actually in effect today.
        draft = ProgramScheduler.shared.effectiveWeeklySchedule()
    }

    private func runSuggest() async {
        guard !isSuggesting else { return }
        let programFocusIds = skillProgress.programFocusIds
        withAnimation(.easeInOut(duration: 0.15)) {
            isSuggesting = true
            suggestErrorVisible = false
        }
        let suggested = ProgramScheduler.shared.optimizedWeeklySchedule(programFocusIds: programFocusIds)
        if suggested.count == 7 {
            draft = suggested
            UnboundHaptics.medium()
        } else {
            LoggingService.shared.log(
                "optimizedWeeklySchedule returned invalid count",
                level: .warning
            )
            withAnimation(.easeInOut(duration: 0.15)) {
                suggestErrorVisible = true
            }
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            isSuggesting = false
        }
    }

    private func save() async {
        // Persist all 7 picks. Even if the user didn't change a slot, we
        // store the resolved value so the schedule survives default tweaks.
        let payload: [DayCategory?] = draft.map { Optional($0) }
        await SkillProgressService.shared.setWeeklySchedule(payload)
        UnboundHaptics.medium()
        dismiss()
    }

    private func resetToDefault() async {
        let nilled: [DayCategory?] = Array(repeating: nil, count: 7)
        await SkillProgressService.shared.setWeeklySchedule(nilled)
        UnboundHaptics.medium()
        dismiss()
    }
}

// MARK: - WeekPhasePickerSheet (V4)

private struct WeekPhasePickerSheet: View {
    let current: WeekPhase
    let onPick: (WeekPhase) -> Void

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("WEEK PHASE")
                    .font(Font.unbound.titleS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Sets the intensity for this week's AI sessions.")
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                VStack(spacing: 8) {
                    ForEach(WeekPhase.allCases) { phase in
                        phaseRow(phase: phase)
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func phaseRow(phase: WeekPhase) -> some View {
        let isCurrent = phase == current
        return Button {
            UnboundHaptics.soft()
            onPick(phase)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: phase.glyph)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isCurrent ? Color.unbound.accent : Color.unbound.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.displayName.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(phase.description)
                        .font(Font.unbound.captionS)
                        .tracking(0.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isCurrent ? Color.unbound.accent.opacity(0.12) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isCurrent ? Color.unbound.accent.opacity(0.45) : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DayCategoryPickerSheet (V4)
//
// Sheet for picking a category for a single day in the editor. Replaces
// the inline horizontal chip scroller from V3 — drag-to-reorder needs
// the row to be tap-and-hold-to-drag, so a separate sheet is cleaner.

private struct DayCategoryPickerSheet: View {
    let dayLabel: String
    let current: DayCategory
    let onPick: (DayCategory) -> Void

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(dayLabel)
                    .font(Font.unbound.titleS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Pick the category for this day.")
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                VStack(spacing: 8) {
                    ForEach(DayCategory.allCases) { cat in
                        catRow(category: cat)
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func catRow(category: DayCategory) -> some View {
        let isCurrent = category == current
        return Button {
            UnboundHaptics.soft()
            onPick(category)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.glyph)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isCurrent ? Color.unbound.accent : Color.unbound.textSecondary)
                    .frame(width: 28)
                Text(category.displayName.uppercased())
                    .font(Font.unbound.bodyMStrong)
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isCurrent ? Color.unbound.accent.opacity(0.12) : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isCurrent ? Color.unbound.accent.opacity(0.45) : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
