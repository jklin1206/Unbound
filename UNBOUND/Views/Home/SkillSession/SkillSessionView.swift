import SwiftUI

// MARK: - SkillSessionView
//
// Full modal session logger for a skill. Surfaced from SkillDetailView's
// "TRAIN" button. Pulls the authored SkillTrainingPlan and lays out a
// SINGLE workout list (the day's main work). Regressions and accessories
// are collapsed by default and only revealed if the user wants them — so
// the session feels like one cluster of work, not three sections.
//
// Sticky bottom: FINISH SESSION → emits PerformanceLog through the unified
// completion service, which preserves SessionLog compatibility during migration.

struct SkillSessionView: View {
    let skillId: String
    let skillTitle: String
    let draft: TrainingSessionDraft

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var services: ServiceContainer
    @Bindable private var skillProgress = SkillProgressService.shared
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    // MARK: Session state

    @State var sessionStart: Date = Date()
    @State var elapsed: Int = 0
    @State var elapsedTimer: Timer? = nil

    /// Logged sets per prescription (keyed by AIExercise id, slot index → set).
    @State var loggedSets: [String: [Int: LoggedSet]] = [:]
    /// Which slot is currently being logged (for the inline editor).
    @State var activeSlot: ActiveSlot? = nil
    /// Bottom rest/combat timer shown after logging a set.
    @State private var activeRest: RestCombatState? = nil

    @State var isDiscardAlertPresented: Bool = false
    @State var isFinishing: Bool = false
    @State var finishErrorMessage: String? = nil
    @State var pendingCompletionLogId: String? = nil

    // Program-style reward sequence shown after every completed skill session.
    @State var rewardSequence: WorkoutRewardSequenceSummary? = nil

    // Helper-section disclosure
    @State var isAccessoriesExpanded: Bool = false

    // Exercise explainer
    @State var explainerExercise: ExplainerPayload? = nil

    // AI session state
    @State var aiSession: AISession? = nil
    @State var isLoadingSession: Bool = true
    @State var loadError: String? = nil

    init(skillId: String, skillTitle: String) {
        self.skillId = skillId
        self.skillTitle = skillTitle
        self.draft = TrainingSessionAdapters.draft(
            forSkillId: skillId,
            title: skillTitle,
            userId: AuthService.shared.currentUserId ?? "",
            plan: SkillTrainingPlanLibrary.plan(for: skillId)
        )
    }

    init(draft: TrainingSessionDraft) {
        let block = draft.blocks.first(where: { $0.kind == .skill })
        self.skillId = block?.skillId ?? draft.blocks.first?.skillId ?? draft.id
        self.skillTitle = block?.title ?? draft.title
        self.draft = draft
    }

    // MARK: Computed

    private var mainExercises: [AIExercise] {
        aiSession?.exercises.filter { !$0.isAccessory } ?? []
    }

    private var accessoryExercises: [AIExercise] {
        aiSession?.exercises.filter { $0.isAccessory } ?? []
    }

    private var hasAccessories: Bool { !accessoryExercises.isEmpty }

    /// Total prescribed slots across the day's main sets.
    var totalSlots: Int {
        mainExercises.reduce(0) { $0 + $1.setsCount }
    }

    /// How many of those slots have been logged.
    var loggedCount: Int {
        loggedSets.values.reduce(0) { $0 + $1.count }
    }

    var canFinish: Bool { loggedCount > 0 }

    // MARK: - Body

    var body: some View {
        Group {
            if let rewardSequence {
                WorkoutRewardSequenceView(summary: rewardSequence) {
                    self.rewardSequence = nil
                    dismiss()
                }
            } else {
                sessionBody
            }
        }
    }

    private var sessionBody: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .background(Color.unbound.bg)

                ScrollView {
                    VStack(spacing: 20) {
                        if isLoadingSession {
                            loadingState
                        } else if let session = aiSession {
                            if !session.summary.isEmpty {
                                summaryCard(session)
                            }
                            todaysWorkList(mainExercises)

                            if hasAccessories {
                                accessoriesDisclosure(accessoryExercises)
                            }
                        } else {
                            genericFallback
                        }

                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            finishBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(
                    LinearGradient(
                        colors: [Color.unbound.bg.opacity(0), Color.unbound.bg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .overlay(alignment: .bottom) {
            if let rest = activeRest {
                RestCombatBanner(
                    state: rest,
                    onExtend: {
                        activeRest?.targetRestSeconds += 30
                        UnboundHaptics.soft()
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            activeRest = nil
                        }
                        UnboundHaptics.medium()
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 84)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(12)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: activeRest)
        .onAppear {
            sessionStart = Date()
            elapsed = 0
            startTimer()
            if aiSession == nil {
                Task { await loadSession(forceRefresh: false) }
            }
        }
        .onDisappear { stopTimer() }
        .alert("Discard this session?", isPresented: $isDiscardAlertPresented) {
            Button("Keep training", role: .cancel) {}
            Button("Discard", role: .destructive) {
                stopTimer()
                dismiss()
            }
        } message: {
            Text("You've logged \(loggedCount) set\(loggedCount == 1 ? "" : "s"). They won't be saved.")
        }
        .alert("Couldn't save session", isPresented: Binding(
            get: { finishErrorMessage != nil },
            set: { if !$0 { finishErrorMessage = nil } }
        )) {
            Button("Retry") { Task { await finish() } }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text(finishErrorMessage ?? "Your session is still here. Try again when the connection is stable.")
        }
        .fullScreenCover(item: $activeSlot) { slot in
            SetLoggerSheet(
                prescription: prescription(for: slot.prescriptionId),
                existing: loggedSets[slot.prescriptionId]?[slot.slotIndex],
                onSave: { newSet in
                    let rx = prescription(for: slot.prescriptionId)
                    let wasEmpty = loggedSets[slot.prescriptionId]?[slot.slotIndex] == nil
                    var bucket = loggedSets[slot.prescriptionId] ?? [:]
                    bucket[slot.slotIndex] = newSet
                    loggedSets[slot.prescriptionId] = bucket
                    activeSlot = nil
                    if wasEmpty {
                        activeRest = RestCombatState(
                            exerciseName: rx?.exerciseName ?? skillTitle,
                            setNumber: slot.slotIndex + 1,
                            targetRestSeconds: max(20, rx?.restSeconds ?? 90),
                            startedAt: Date()
                        )
                    }
                    UnboundHaptics.medium()
                },
                onCancel: { activeSlot = nil }
            )
        }
        .onChange(of: aiSession?.skillId) { _, _ in
            // Drop any logged sets if the session content changes (regenerate).
            loggedSets = [:]
            sessionStart = Date()
            elapsed = 0
        }
        .sheet(item: $explainerExercise) { payload in
            ExerciseExplainerSheet(payload: payload) {
                explainerExercise = nil
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - ActiveSlot


// MARK: - ExplainerPayload


// MARK: - SetLoggerSheet
//
// Tightened editor for a single set. One vertical column — primary input,
// weight chips, RPE chips. No section eyebrows beyond the chips' own labels.
