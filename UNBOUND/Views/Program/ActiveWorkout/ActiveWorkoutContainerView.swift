import SwiftUI

// MARK: - ActiveWorkoutContainerView
//
// Session orchestrator for the new grid-based logging surface.
// Owns the ActiveWorkoutSession, autosaves drafts, hosts WorkoutLogGridView
// + timer chrome, and on COMPLETE assembles + saves unified
// PerformanceLog data before showing the post-workout reward sequence.

struct ActiveWorkoutContainerView: View {
    @StateObject var session: ActiveWorkoutSession
    @State var priorEntries: [ExerciseLogEntry] = []
    @State var workingWeightKg: Double? = nil
    @State var saving = false
    @State var showCompleteConfirm = false
    @State var saveError = false
    @State var showExitConfirm = false
    @State var draftAutosaveFailed = false

    // Swap sheet state
    @State var swapExerciseIndex: Int? = nil
    @State var swapAlternatives: [CatalogExercise] = []
    /// The user's gear, loaded once on appear, so the swap picker can flag
    /// equipment-incompatible alternatives. nil = no filter (graceful default).
    @State var swapEquipment: [Equipment]? = nil
    @State private var showingCustomBuilder = false
    @State var showingAddExercise = false

    // Notes editing state
    @State var notesEditingIndex: Int? = nil
    @State var notesEditingText: String = ""
    @State var showNotesSheet = false

    // Reward state
    @State var rewardSequence: WorkoutRewardSequenceSummary? = nil
    @State var isFinishingRewardSequence = false

    // A passed rank gate: The Crossing overrides the standard reward sequence as the
    // rank-up moment, then chains into it so XP/badges still play.
    @State var pendingGateCrossing: GateCrossing? = nil
    @State var pendingGateDefiningNumber: String? = nil
    @State var stashedGateRewardSummary: WorkoutRewardSequenceSummary? = nil

    /// Station-clear beat (spec §6.5): the world floods full-bleed when a rank-trial
    /// station's first working set is logged, then recedes (`GateBeatOverlay`).
    @State private var beatStationTitle: String? = nil

    /// Fail verdict (spec §6.7): "THE GATE HOLDS" → ENTER AGAIN on a failed gate.
    @State var pendingGateVerdict: GateVerdictContext? = nil

    struct GateVerdictContext: Identifiable {
        let id = UUID()
        let evaluation: OverallRankTrialEvaluation
        let world: GateWorld
        var spoils: String? = nil
    }

    // Grid cell editor — shared bottom-docked keypad module (no modal). The model
    // owns the typed buffer + pristine state, so merely opening a cell never
    // commits the suggested value (the ✓ ring does that).
    @StateObject var keypad = NumberPadEditorModel<ActiveCell>()

    // Rest timer
    @ObservedObject var restTimer = RestTimerModel.shared
    @State var workoutElapsedSeconds = 0
    private let restClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Environment(\.dismiss) var dismiss
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue
    @AppStorage(WeightPlatePolicy.microloadingDefaultsKey) var microloadingEnabled = false

    let services: ServiceContainer
    let draftStore: WorkoutDraftStore
    let onFinished: (() -> Void)?
    /// A failed rank gate's ENTER AGAIN. The presenter rebuilds a fresh trial
    /// container (new session identity, new performance-log id) so the retry is
    /// a genuinely new attempt; nil falls back to dismissing.
    private let onGateRematch: (() -> Void)?
    /// Rehearsal = the onboarding taste of logging. The full surface behaves
    /// normally, but finishing writes nothing (no performance log, no XP, no
    /// reward sequence) and drafts are never autosaved for crash recovery.
    let isRehearsal: Bool

    // MARK: - Private types

    /// One editable cell in the logging grid: a weight cell, a metric cell, or the
    /// RPE quick-pick. Drives the shared NumberPadEditorModel.
    struct ActiveCell: Equatable, Identifiable {
        enum Field: Equatable { case weight, metric, rpe }
        let ei: Int
        let si: Int
        let field: Field
        var id: String { "\(ei)-\(si)-\(field)" }
        var isWeight: Bool { field == .weight }
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
        self.onGateRematch = nil
        self.isRehearsal = false
        _session = StateObject(
            wrappedValue: resuming
                ?? ActiveWorkoutSession(workout: workout, programId: programId, dayNumber: dayNumber)
        )
    }

    init(
        draft: TrainingSessionDraft,
        services: ServiceContainer,
        isRehearsal: Bool = false,
        onFinished: (() -> Void)? = nil,
        onGateRematch: (() -> Void)? = nil
    ) {
        self.services = services
        self.draftStore = WorkoutDraftStore()
        self.onFinished = onFinished
        self.onGateRematch = onGateRematch
        self.isRehearsal = isRehearsal
        _session = StateObject(wrappedValue: ActiveWorkoutSession(trainingDraft: draft))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                workoutTopBar

                if draftAutosaveFailed {
                    draftAutosaveWarning
                }

                if isCustomSession && visibleExerciseCount == 0 {
                    emptyQuickLogState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    WorkoutLogGridView(
                        session: session,
                        rankTrialDefinition: rankTrialDefinition,
                        onIntent: { ei, intent in handleIntent(ei, intent) },
                        onEditWeight: { ei, si in beginEdit(ei: ei, si: si, field: .weight) },
                        onEditReps:   { ei, si in beginEdit(ei: ei, si: si, field: .metric) },
                        onPickRPE: { ei, si in beginEdit(ei: ei, si: si, field: .rpe) },
                        onConfirmAsPlanned: { ei, si in
                            session.confirmAsPlanned(exerciseIndex: ei, setIndex: si)
                            saveDraft()
                            // Rank trials auto-finish into the verdict / Crossing once every
                            // station is logged — no manual "Complete Trial" tap.
                            if isRankTrial && !session.hasUnloggedWorkingSets {
                                restTimer.stop()
                                Task { await complete() }
                            } else {
                                transition(ei: ei, si: si)
                            }
                        },
                        onToggleQualityFlag: { ei, si, flag in
                            session.toggleQualityFlag(flag, exerciseIndex: ei, setIndex: si)
                            saveDraft()
                        },
                        onAddSet: { ei in
                            session.addSet(toExerciseIndex: ei)
                            saveDraft()
                        },
                        // Rehearsal included: the onboarding demo should
                        // showcase the whole mission list at a glance, not
                        // boot into one expanded card's anatomy chart.
                        startsFirstExerciseExpanded: false
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Hide the bottom footer while the keypad owns that space (matches the
            // pre-module behaviour where the dock floated over the footer).
            if !keypad.isActive {
                if isRankTrial {
                    trialRestFooter
                } else if isCustomSession && visibleExerciseCount == 0 {
                    // Empty Quick Log: the body shows the Add Exercise CTA, so the
                    // finish footer is hidden — there's nothing to finish yet.
                    EmptyView()
                } else {
                    completionFooter
                }
            }
        }
        .numberPadDock(model: keypad)
        .onReceive(restClock) { now in
            restTimer.tick(now: now)
            workoutElapsedSeconds = Self.elapsedSeconds(since: session.startedAt, now: now)
        }
        .task {
            workoutElapsedSeconds = Self.elapsedSeconds(since: session.startedAt)
            await loadContext()
        }
        .task {
            // Never during the onboarding rehearsal - the deliberate ask lives
            // on the notifications step, and a permission dialog rising over
            // the taste-the-loop demo reads as a bug.
            guard !isRehearsal else { return }
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
        .onChange(of: rankTrialClearedStations) { previous, current in
            // A station just cleared — flood its world beat. Deck has its own flow.
            guard isRankTrial, !isDeckTrial, current > previous else { return }
            beatStationTitle = session.exercises.last { !$0.skipped && $0.hasLoggedRankTrialWorkingSet }?.name
        }
        .overlay {
            if let beatStationTitle, let gateWorld {
                GateBeatOverlay(world: gateWorld, stationTitle: beatStationTitle) {
                    self.beatStationTitle = nil
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
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
        // Grid cell editing + RPE now use the shared bottom-docked keypad module
        // (.numberPadDock(model: keypad)), not modal sheets.
        // Swap sheet — uses the existing ExerciseSwapSheet with real init
        .fullScreenCover(item: Binding(
            get: { swapExerciseIndex.map(SwapContext.init(index:)) },
            set: { swapExerciseIndex = $0?.index }
        )) { ctx in
            ExerciseSwapSheet(
                currentExerciseName: session.exercises[ctx.index].name,
                alternatives: swapAlternatives,
                onSelect: { alt in
                    session.replaceExercise(at: ctx.index, with: alt)
                    swapExerciseIndex = nil
                    saveDraft()
                },
                availableEquipment: swapEquipment,
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
                saveDraft()
            }
                .environmentObject(services)
        }
        // Live "Add Exercise" picker for free/Quick-Log sessions — reuses the
        // same catalog picker the session editor uses.
        .fullScreenCover(isPresented: $showingAddExercise) {
            ExerciseSwapSheet(
                mode: .addMulti,
                currentExerciseName: "Quick Log",
                alternatives: addExerciseCatalog,
                onSelect: { exercise in
                    session.appendCatalogExercise(exercise)
                    saveDraft()
                },
                onDeselect: { exercise in
                    session.removeLastAddedExercise(matching: exercise.displayName)
                    saveDraft()
                },
                onCreateCustom: {
                    showingAddExercise = false
                    showingCustomBuilder = true
                }
            )
        }
        // Notes editing sheet — simple inline text entry
        .sheet(isPresented: $showNotesSheet) {
            NotesEditSheet(
                text: $notesEditingText,
                onSave: {
                    if let idx = notesEditingIndex {
                        session.setNotes(notesEditingText, forExerciseAt: idx)
                        saveDraft()
                    }
                    showNotesSheet = false
                },
                onCancel: {
                    showNotesSheet = false
                }
            )
        }
        .fullScreenCover(item: $rewardSequence) { summary in
            WorkoutRewardSequenceView(
                summary: summary,
                onAddWorkoutPhoto: { image in
                    Task { await saveWorkoutPhoto(image, context: summary.workoutPhotoContext, services: services) }
                }
            ) {
                finishRewardSequence()
            }
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(item: $pendingGateCrossing) { crossing in
            TheCrossingView(
                crossing: crossing,
                definingNumber: pendingGateDefiningNumber,
                onReplay: {},
                onDismiss: {
                    pendingGateCrossing = nil
                    if let stashed = stashedGateRewardSummary {
                        stashedGateRewardSummary = nil
                        rewardSequence = stashed   // chain into XP / badges
                    } else {
                        finishDismiss()
                    }
                }
            )
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(item: $pendingGateVerdict) { context in
            GateVerdictView(
                evaluation: context.evaluation,
                world: context.world,
                spoilsLine: context.spoils,
                onRematch: {
                    pendingGateVerdict = nil
                    if let onGateRematch {
                        onGateRematch()
                    } else {
                        finishDismiss()
                    }
                }
            )
            .interactiveDismissDisabled(true)
        }
    }

    /// Same catalog the session editor's ADD EXERCISE picker draws from.
    private var addExerciseCatalog: [CatalogExercise] {
        MovementCatalog.legacyExercises.compactMap(MovementCatalog.catalogExercise(for:))
    }
}
