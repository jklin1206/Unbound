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

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: ServiceContainer
    @Bindable private var skillProgress = SkillProgressService.shared

    // MARK: Session state

    @State private var sessionStart: Date = Date()
    @State private var elapsed: Int = 0
    @State private var elapsedTimer: Timer? = nil

    /// Logged sets per prescription (keyed by AIExercise id, slot index → set).
    @State private var loggedSets: [String: [Int: LoggedSet]] = [:]
    /// Which slot is currently being logged (for the inline editor).
    @State private var activeSlot: ActiveSlot? = nil
    /// Bottom rest/combat timer shown after logging a set.
    @State private var activeRest: RestCombatState? = nil

    @State private var isDiscardAlertPresented: Bool = false
    @State private var isFinishing: Bool = false
    @State private var finishErrorMessage: String? = nil
    @State private var pendingCompletionLogId: String? = nil

    // Program-style reward sequence shown after every completed skill session.
    @State private var rewardSequence: WorkoutRewardSequenceSummary? = nil

    // Helper-section disclosure
    @State private var isAccessoriesExpanded: Bool = false

    // Exercise explainer
    @State private var explainerExercise: ExplainerPayload? = nil

    // AI session state
    @State private var aiSession: AISession? = nil
    @State private var isLoadingSession: Bool = true
    @State private var loadError: String? = nil

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
    private var totalSlots: Int {
        mainExercises.reduce(0) { $0 + $1.setsCount }
    }

    /// How many of those slots have been logged.
    private var loggedCount: Int {
        loggedSets.values.reduce(0) { $0 + $1.count }
    }

    private var canFinish: Bool { loggedCount > 0 }

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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                if loggedCount > 0 {
                    isDiscardAlertPresented = true
                } else {
                    UnboundHaptics.soft()
                    stopTimer()
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.9)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY'S SESSION")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                HStack(spacing: 6) {
                    Text(skillTitle)
                        .font(.system(.title3).weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if aiSession?.isAIGenerated == true {
                        aiBadge
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    UnboundHaptics.soft()
                    Task { await loadSession(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .disabled(isLoadingSession)

                Text(formatElapsed(elapsed))
                    .font(Font.unbound.monoM)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var aiBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text("AI")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(0.8)
        }
        .foregroundStyle(Color.unbound.accent)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(Color.unbound.accent.opacity(0.14))
        )
        .overlay(
            Capsule().strokeBorder(Color.unbound.accent.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Today's work (the single workout list)

    @ViewBuilder
    private func todaysWorkList(_ items: [AIExercise]) -> some View {
        VStack(spacing: 12) {
            ForEach(items) { ex in
                workoutRow(ex)
            }
        }
    }

    /// One row per exercise: name (tap → explainer), one-line target meta,
    /// and a horizontal slot-chip strip to log every set inline.
    private func workoutRow(_ ex: AIExercise) -> some View {
        let logged = loggedSets[ex.id] ?? [:]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    UnboundHaptics.soft()
                    explainerExercise = ExplainerPayload(
                        name: ex.name,
                        description: ex.description,
                        cues: ex.cues,
                        notes: ex.notes
                    )
                } label: {
                    HStack(spacing: 6) {
                        Text(ex.name)
                            .font(Font.unbound.bodyLStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                if logged.count == ex.setsCount {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
            }

            Text(targetSummary(ex))
                .font(Font.unbound.captionS.weight(.semibold))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textSecondary)

            slotsRow(ex: ex, logged: logged)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    /// "5 sets × 3 reps · 120s rest" / "3 × max hold · 60s rest"
    private func targetSummary(_ ex: AIExercise) -> String {
        "\(ex.setsCount) sets × \(ex.target.displayString) · \(ex.restSeconds)s rest"
    }

    private func slotsRow(ex: AIExercise, logged: [Int: LoggedSet]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(max(ex.setsCount, 1), 5))
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<ex.setsCount, id: \.self) { idx in
                slotChip(ex: ex, idx: idx, logged: logged[idx])
            }
        }
    }

    private func slotChip(ex: AIExercise, idx: Int, logged: LoggedSet?) -> some View {
        Button {
            UnboundHaptics.soft()
            activeSlot = ActiveSlot(prescriptionId: ex.id, slotIndex: idx)
        } label: {
            VStack(spacing: 2) {
                Text("SET \(idx + 1)")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(
                        logged == nil
                            ? Color.unbound.textTertiary
                            : Color.unbound.accent
                    )
                if let logged {
                    Text(loggedSummary(logged, target: ex.target))
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("—")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(logged == nil
                        ? Color.unbound.surfaceElevated.opacity(0.5)
                        : Color.unbound.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        logged == nil
                            ? Color.unbound.border
                            : Color.unbound.accent.opacity(0.6),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func loggedSummary(_ s: LoggedSet, target: AIPrescriptionTarget) -> String {
        switch target {
        case .hold:
            let secs = s.holdSeconds ?? 0
            return "\(secs)s"
        default:
            if let kg = s.weightKg, kg > 0 {
                return "\(s.reps) · \(formatKg(kg))"
            }
            return "\(s.reps) reps"
        }
    }

    private func formatKg(_ kg: Double) -> String {
        if kg == floor(kg) {
            return "\(Int(kg))kg"
        }
        return String(format: "%.1fkg", kg)
    }

    // MARK: - Disclosure sections (regressions / accessories)

    @ViewBuilder
    private func accessoriesDisclosure(_ items: [AIExercise]) -> some View {
        VStack(spacing: 0) {
            Button {
                UnboundHaptics.soft()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                    isAccessoriesExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isAccessoriesExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Optional Accessories")
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text("Add-on work for extra volume — skip if pressed for time")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(roundedCard)
            }
            .buttonStyle(.plain)

            if isAccessoriesExpanded {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        helperRow(item)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func helperRow(_ ex: AIExercise) -> some View {
        Button {
            UnboundHaptics.soft()
            explainerExercise = ExplainerPayload(
                name: ex.name,
                description: ex.description,
                cues: ex.cues,
                notes: ex.notes
            )
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 18, alignment: .center)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(ex.name)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text("\(ex.setsCount) × \(ex.target.displayString)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(roundedCard)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading + summary

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.unbound.accent)
                .scaleEffect(1.3)
            Text("Generating today's session…")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
            if let err = loadError {
                Text(err)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func summaryCard(_ session: AISession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY'S FOCUS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.accent)
            Text(session.summary)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("~\(session.estimatedDurationMinutes) min")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    // MARK: - Generic fallback

    private var genericFallback: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No detailed plan yet")
                .font(.system(.headline).weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
            Text("This skill doesn't have a structured training plan in V1. Train the movement on your own — sets, reps, holds — and tap FINISH SESSION when you're done.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    // MARK: - Finish bar

    private var finishBar: some View {
        let title: String
        if !canFinish {
            title = "Log a set to finish"
        } else if isFinishing {
            title = "Saving session"
        } else if loggedCount == totalSlots && totalSlots > 0 {
            title = "Finish session"
        } else {
            title = "Finish session (\(loggedCount)/\(totalSlots))"
        }
        return UnboundButton(
            title: title,
            icon: "checkmark.seal.fill",
            isEnabled: canFinish && !isFinishing
        ) {
            Task { await finish() }
        }
        .accessibilityIdentifier("skillSession.finish")
    }

    // MARK: - Finish flow

    private func finish() async {
        guard !isFinishing else { return }
        isFinishing = true
        finishErrorMessage = nil
        stopTimer()

        let realNow = Date()
        #if DEBUG
        let now = DevProgramClock.now
        #else
        let now = realNow
        #endif
        let duration = Int(realNow.timeIntervalSince(sessionStart))
        let adjustedSessionStart = now.addingTimeInterval(-TimeInterval(duration))
        guard let userId = AuthService.shared.currentUserId else {
            isFinishing = false
            finishErrorMessage = "Sign in before finishing a skill session."
            HapticManager.notification(.error)
            return
        }

        // Build LoggedExercise entries grouped by exercise name. Pull from
        // every exercise that has at least one logged slot — mains AND any
        // accessory the user actually completed.
        var loggedExercises: [LoggedExercise] = []
        if let session = aiSession {
            for ex in session.exercises {
                let bucket = loggedSets[ex.id] ?? [:]
                guard !bucket.isEmpty else { continue }
                let sortedSets = bucket
                    .sorted(by: { $0.key < $1.key })
                    .map(\.value)
                loggedExercises.append(
                    LoggedExercise(name: ex.name, sets: sortedSets)
                )
            }
        }

        // XP: 25 × completion fraction. Cap at 25, floor at 1 if anything logged.
        let xp = computeXP()

        // Snapshot before write. Look up the canonical node for hold-based
        // detection (the earned tier is read from the tier store inside before/after).
        let node = SkillGraph.shared.node(id: skillId)
        let isHoldBased: Bool = {
            if case .hold = node?.target { return true }
            return false
        }()

        let preSnapshot = await RewardComputer.shared.before(
            skillId: skillId,
            isHoldBased: isHoldBased,
            userId: userId,
            badgeService: services.badges
        )

        let completionLogId = pendingCompletionLogId ?? UUID().uuidString
        pendingCompletionLogId = completionLogId

        let performanceLog = TrainingSessionAdapters.performanceLogForSkillSession(
            id: completionLogId,
            userId: userId,
            skillId: skillId,
            skillTitle: skillTitle,
            startedAt: adjustedSessionStart,
            completedAt: now,
            durationSeconds: duration,
            exercises: loggedExercises,
            selectedRungId: aiSession?.selectedRungId,
            selectedRungSource: aiSession?.selectedRungSource,
            selectedRungReason: aiSession?.selectedRungReason
        )

        let completionResult: TrainingCompletionResult
        do {
            completionResult = try await TrainingCompletionService.shared.complete(
                performanceLog,
                services: services,
                skillXPAwarded: xp
            )
        } catch {
            isFinishing = false
            finishErrorMessage = error.localizedDescription
            HapticManager.notification(.error)
            return
        }

        let compatibleLog = TrainingSessionAdapters.sessionLogs(from: performanceLog, xpAwarded: xp).first

        // Fire badge evaluation — sessionLogged trigger expects a
        // WorkoutLog (legacy). For now, fire setCompleted for the
        // best set in the session — that's what the catalog evaluators
        // actually consume.
        let bestSet = compatibleLog.flatMap { RewardComputer.bestSet(from: $0, isHoldBased: isHoldBased) }
        var unlocked: [Badge] = []
        if let bs = bestSet {
            let triggerKey = isHoldBased ? "\(skillId).hold" : skillId
            let triggerReps = isHoldBased ? (bs.holdSeconds ?? 0) : bs.reps
            unlocked = await services.badges.evaluate(
                trigger: .setCompleted(exerciseKey: triggerKey, reps: triggerReps)
            )
        }

        var summary = await RewardComputer.shared.after(
            snapshot: preSnapshot,
            skillTitle: skillTitle,
            bestSet: bestSet ?? LoggedSet(reps: 0, holdSeconds: nil, weightKg: nil, rpe: nil),
            xpGained: completionResult.skillXPGained,
            unlockedBadges: unlocked
        )
        summary.progression = completionResult.progressionReceipt

        UnboundHaptics.medium()
        pendingCompletionLogId = nil

        rewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: summary,
            fallbackXP: xp,
            sourceName: "Skill Session"
        )
    }

    private func computeXP() -> Int {
        guard totalSlots > 0 else {
            // Generic fallback / no plan — give the standard award.
            return 25
        }
        let fraction = Double(loggedCount) / Double(totalSlots)
        let raw = 25.0 * fraction
        let rounded = Int(raw.rounded())
        // If they logged anything, give at least 1 XP so the work counts.
        if loggedCount > 0 {
            return max(1, rounded)
        }
        return 0
    }

    // MARK: - Helpers

    private func prescription(for id: String) -> TrainingPrescription? {
        guard let ex = aiSession?.exercises.first(where: { $0.id == id }) else { return nil }
        return ex.asLegacyPrescription
    }

    /// Loads (or regenerates) today's AI session. Drops any logged sets when
    /// the session is replaced so the slot strip rehydrates against fresh
    /// prescriptions.
    private func loadSession(forceRefresh: Bool) async {
        guard let userId = AuthService.shared.currentUserId else {
            isLoadingSession = false
            loadError = "Sign in before starting a skill session."
            return
        }
        isLoadingSession = true
        loadError = nil
        if forceRefresh {
            loggedSets = [:]
            sessionStart = Date()
            elapsed = 0
        }
        do {
            let session = try await RPESessionService.shared.session(
                forSkillId: skillId,
                userId: userId,
                forceRefresh: forceRefresh
            )
            self.aiSession = session
        } catch {
            loadError = error.localizedDescription
            // Fallback path inside the service catches most cases — but if the
            // service itself rethrows, surface a generic AMRAP shell so the
            // user can still log work.
            self.aiSession = AISession(
                skillId: skillId,
                generatedAt: Date(),
                summary: "Train today's skill — quality over volume.",
                estimatedDurationMinutes: 20,
                exercises: [
                    AIExercise(
                        name: skillTitle,
                        description: "Train the skill directly. Log what you hit.",
                        cues: [],
                        setsCount: 3,
                        target: .amrap,
                        restSeconds: 90,
                        notes: nil,
                        isAccessory: false
                    )
                ],
                isAIGenerated: false
            )
        }
        isLoadingSession = false
    }

    private func startTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsed = Int(Date().timeIntervalSince(sessionStart))
            }
        }
    }

    private func stopTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func formatElapsed(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    // MARK: - Styling

    private var roundedCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        }
    }
}

// MARK: - ActiveSlot


// MARK: - ExplainerPayload


// MARK: - SetLoggerSheet
//
// Tightened editor for a single set. One vertical column — primary input,
// weight chips, RPE chips. No section eyebrows beyond the chips' own labels.
