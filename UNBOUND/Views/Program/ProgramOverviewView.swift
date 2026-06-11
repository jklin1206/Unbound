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

    /// Observe the singleton so Program Focus state stays in sync when the
    /// user changes skill training from the detail screen.
    @Bindable var skillProgress = SkillProgressService.shared

    @State var viewModel: ProgramViewModel?
    @State var currentProfile: UserProfile?
    @State var selectedTab: Tab = .program
    @State var selectedDay: ProgramDay?
    @State var showPaywall = false
    @State var showRationale = false
    @State var workoutReadyDraft: TrainingSessionDraft?
    @State var activeWorkoutDraft: TrainingSessionDraft?
    @State var sessionEditorDraft: TrainingSessionDraft?
    @State var savedWorkoutEditorDraft: TrainingSessionDraft?
    @State var planningWorkoutDraft: TrainingSessionDraft?
    @State var savedWorkoutLibraryRevision = 0
    @State var schedulingWorkout: SavedWorkout?

    @State var showMonthPlanner = false
    @State var showExerciseStarterLibrary = false
    @State var exerciseStarterAlternativesCache: [CatalogExercise] = []
    @State var exerciseStarterAlternativesCacheKey = ""
    @State var recoveryRewardSequence: WorkoutRewardSequenceSummary?
    @State var isCompletingRecoveryDay = false
    @State var programScheduleRevision = 0

    // Program Focus detail launcher state.
    @State var pushedSkillNode: SkillNode?

    // V3 — schedule editor sheets.
    @State var showScheduleEditor: Bool = false
    @State var focusSwitchPresentation: ProgramFocusSwitchPresentation?
    @State var isSwitchingProgramFocus = false
    @State var focusSwitchErrorMessage: String?
    @State var temporaryContextRevision = 0
    @State var planningTargetDate: Date?

    // Program view state
    @State var weekOffset: Int = 0 // +1 = next week, -1 = prev
    @State var selectedDayDate: Date = Self.initialSelectedDayDate()
    #if DEBUG
    @State var devDayOffset: Int = DevProgramClock.dayOffset
    @State var activeDevDynamicScenarioRawValue: String = UserDefaults.standard.string(forKey: DevDynamicProgramScenario.activeUserDefaultsKey) ?? ""
    @State var isSeedingDevDynamicScenario = false
    #endif

    // Completed-log cache. Still feeds checkpoint/recovery context even
    // though the old calendar tab is no longer surfaced.
    @State var pastLogs: [WorkoutLog] = []

    // Travel override (user hit the TRAVEL coach action)
    @State var activeTravelOverride: TravelOverride?

    // Routines view state
    @State var activeRoutinePlayer: RoutineDef?
    @State var selectedChallengeId: String = "daily-quest"
    @State var selectedRoutineIdsByCategory: [RoutineCategory: String] = [:]
    @State var travelingRoutine: RoutineDef?
    @State var routineTravelProgress: CGFloat = 0
    #if DEBUG
    @State var debugOpenedRoutine = false
    #endif

    // Block rollover (Chunk 3): block-complete CTA + optional rescan + share.
    @State var isGeneratingNextBlock: Bool = false
    @State var showRescanFlow: Bool = false
    @State var showCheckpointFlow: Bool = false
    @State var rolloverDeltaReport: ScanDeltaReport?
    @State var rolloverProposal: BlockRolloverService.ProgramBlockProposal?
    @State var showProgressReveal: Bool = false
    @State var nextBlockNumberPreview: Int = 2
    @State var currentBlockNumberPreview: Int = 1
    @State var dismissedCheckpointPromptProgramId: String?

    // Resume draft affordance.
    @State var resumeDraft: ActiveWorkoutSession?
    let draftStore = WorkoutDraftStore()

    enum Tab: Hashable { case program, myWorkouts, routines }

    private static func initialSelectedDayDate() -> Date {
        #if DEBUG
        return DevProgramClock.today
        #else
        return Calendar.current.startOfDay(for: Date())
        #endif
    }

    var programToday: Date {
        #if DEBUG
        return DevProgramClock.today(offset: devDayOffset)
        #else
        return Calendar.current.startOfDay(for: Date())
        #endif
    }

    var programNow: Date {
        #if DEBUG
        return DevProgramClock.now(offset: devDayOffset)
        #else
        return Date()
        #endif
    }

    var dayResolver: ProgramOverviewDayResolver {
        ProgramOverviewDayResolver(
            userId: services.auth.currentUserId,
            activeTravelOverride: activeTravelOverride,
            scheduleRevision: programScheduleRevision,
            scheduleStore: ProgramScheduleStore.shared
        )
    }

    func isProgramToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: programToday)
    }

    func isProgramPast(_ date: Date) -> Bool {
        date < programToday && !isProgramToday(date)
    }

    func showProgramRationale() {
        UnboundHaptics.soft()
        if viewModel?.program?.rationale != nil {
            showRationale = true
        }
    }

    func reloadProgramSurface() {
        Task { await loadProgramSurface() }
    }

    func openPaywall() {
        showPaywall = true
    }

    func openCheckpointFlow() {
        UnboundHaptics.soft()
        showCheckpointFlow = true
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                programTopBar()
                ProgramOverviewTabSelector(selectedTab: $selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Group {
                    switch selectedTab {
                    case .program:  programTab
                    case .myWorkouts:
                        MyWorkoutsView(
                            refreshTrigger: savedWorkoutLibraryRevision,
                            onQuickLog: {
                                activeWorkoutDraft = QuickLogDraftFactory.empty(userId: services.auth.currentUserId ?? "")
                            },
                            onBuild: {
                                savedWorkoutEditorDraft = SavedWorkoutDraftFactory.empty(userId: services.auth.currentUserId ?? "")
                            },
                            onStartWorkout: { workout in
                                startSavedWorkout(workout)
                            },
                            onSchedule: { workout in
                                schedulingWorkout = workout
                            }
                        )
                    case .routines: routinesTab
                    }
                }
            }

            if let travelingRoutine {
                RoutineTravelOverlay(routine: travelingRoutine, progress: routineTravelProgress)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(3)
            }

            if isCompletingRecoveryDay {
                ProgramRecoveryCompletionOverlay()
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
            openWorkoutsTabIfRequested()
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
        .sheet(isPresented: $showMonthPlanner) {
            ProgramMonthPlannerView(
                workouts: SavedWorkoutStore.shared.all(),
                initialDate: selectedDayDate,
                occurrences: monthPlannerOccurrences(),
                onPlace: { workout, date in
                    placeSavedWorkoutOnCalendar(workout, date: date)
                },
                onMarkRest: { date in
                    markRestDayOnCalendar(date)
                },
                onClearPlan: { date in
                    clearPlannedDayOnCalendar(date)
                },
                onCreateWorkout: {
                    showMonthPlanner = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        openCreateWorkoutEditor()
                    }
                },
                onDismiss: {
                    showMonthPlanner = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
        .sheet(isPresented: $showExerciseStarterLibrary) {
            ExerciseSwapSheet(
                mode: .add,
                currentExerciseName: "Workout",
                alternatives: exerciseStarterSheetAlternatives(program: viewModel?.program),
                onSelect: { exercise in
                    showExerciseStarterLibrary = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        openExerciseStarter(exercise)
                    }
                },
                availableEquipment: currentProfile?.equipment
            )
            .environmentObject(services)
        }
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--unbound-open-editor"), savedWorkoutEditorDraft == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    savedWorkoutEditorDraft = SavedWorkoutDraftFactory.empty(userId: services.auth.currentUserId ?? "")
                }
            } else if args.contains("--unbound-open-active"), activeWorkoutDraft == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if let workout = SavedWorkoutStore().all().first {
                        startSavedWorkout(workout)
                    }
                }
            }
        }
        #endif
        .sheet(item: $schedulingWorkout) { workout in
            ScheduleWorkoutDateSheet(
                workout: workout,
                today: programToday,
                onSchedule: { date in
                    scheduleSavedWorkout(workout, on: date)
                },
                onDismiss: { schedulingWorkout = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
        .onReceive(NotificationCenter.default.publisher(for: .savedWorkoutScheduleTodayRequested)) { note in
            guard let workout = note.object as? SavedWorkout else { return }
            selectedTab = .program
            weekOffset = 0
            selectedDayDate = Calendar.current.startOfDay(for: programToday)
            applySavedWorkout(workout, to: programToday, allowExtraSession: true)
        }
        .fullScreenCover(item: $workoutReadyDraft) { draft in
            WorkoutReadyView(draft: draft)
                .environmentObject(services)
        }
        .fullScreenCover(item: $activeWorkoutDraft) { draft in
            ActiveWorkoutContainerView(draft: draft, services: services) {
                UserDefaults.standard.set(0, forKey: "unbound.shortSessionDate")
                activeWorkoutDraft = nil
                Task { await refreshProgramCompletionState() }
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
        .fullScreenCover(item: $savedWorkoutEditorDraft) { draft in
            SessionEditorView(draft: draft, mode: .saveWorkout) { editedDraft in
                saveWorkoutToLibrary(editedDraft)
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
                programId: viewModel?.program?.id ?? "",
                adjustments: waveAdjustments(for: day),
                onUndoAdjustment: revertWaveAdjustment
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
                activeContext: presentation.activeContext,
                pendingContext: presentation.pendingContext,
                isApplying: isSwitchingProgramFocus,
                errorMessage: focusSwitchErrorMessage,
                onClear: { target in
                    clearFocusContext(target)
                },
                onApply: { selection in
                    Task { await applyFocusSwitch(selection) }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(isSwitchingProgramFocus)
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
}
