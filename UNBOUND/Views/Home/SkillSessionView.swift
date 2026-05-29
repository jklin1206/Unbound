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
            userId: AuthService.shared.currentUserId ?? "anonymous",
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

        let now = Date()
        let duration = Int(now.timeIntervalSince(sessionStart))
        let userId = AuthService.shared.currentUserId ?? "anonymous"

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

        let performanceLog = TrainingSessionAdapters.performanceLogForSkillSession(
            id: UUID().uuidString,
            userId: userId,
            skillId: skillId,
            skillTitle: skillTitle,
            startedAt: sessionStart,
            completedAt: now,
            durationSeconds: duration,
            exercises: loggedExercises
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
        let userId = AuthService.shared.currentUserId ?? "anonymous"
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

private struct ActiveSlot: Identifiable, Equatable {
    let prescriptionId: String
    let slotIndex: Int
    var id: String { "\(prescriptionId)#\(slotIndex)" }
}

// MARK: - RestCombatState

private struct RestCombatState: Identifiable, Equatable {
    let id = UUID()
    let exerciseName: String
    let setNumber: Int
    var targetRestSeconds: Int
    let startedAt: Date
}

// MARK: - RestCombatBanner

private struct RestCombatBanner: View {
    let state: RestCombatState
    let onExtend: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        TimelineView(.periodic(from: state.startedAt, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(state.startedAt)))
            let remaining = state.targetRestSeconds - elapsed
            let progress = max(0, min(1, Double(elapsed) / Double(max(1, state.targetRestSeconds))))
            let phase = phase(for: elapsed)
            let color = color(for: phase)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.unbound.borderSubtle, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(progress, 1)))
                        .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(0.42), radius: 8)
                    VStack(spacing: 0) {
                        Text(remaining >= 0 ? formatClock(remaining) : "+\(formatClock(abs(remaining)))")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .monospacedDigit()
                        Text(phase.label)
                            .font(.system(size: 7, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(color)
                    }
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Text("REST GUARD")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.5)
                            .foregroundStyle(color)
                        Text("SET \(state.setNumber)")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }

                    Text(state.exerciseName.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    RestGuardHealthBar(progress: progress, isOverRest: phase == .over, color: color)
                }

                VStack(spacing: 8) {
                    Button(action: onDismiss) {
                        Image(systemName: phase == .ready ? "bolt.fill" : "forward.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.unbound.bg)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(color))
                    }
                    .buttonStyle(.plain)

                    Button(action: onExtend) {
                        Text("+30")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(width: 38, height: 26)
                            .background(Capsule().fill(Color.unbound.bg.opacity(0.72)))
                            .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.unbound.surface.opacity(0.93))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(color.opacity(0.42), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.22), radius: 18, y: 10)
        }
    }

    private enum Phase {
        case recover, ready, over

        var label: String {
            switch self {
            case .recover: return "REC"
            case .ready: return "GO"
            case .over: return "DRAG"
            }
        }
    }

    private func phase(for elapsed: Int) -> Phase {
        if elapsed < state.targetRestSeconds { return .recover }
        if elapsed <= state.targetRestSeconds + 20 { return .ready }
        return .over
    }

    private func color(for phase: Phase) -> Color {
        switch phase {
        case .recover: return Color.unbound.coachCyan
        case .ready: return Color.unbound.success
        case .over: return Color.unbound.warnOrange
        }
    }

    private func formatClock(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

private struct RestGuardHealthBar: View {
    let progress: Double
    let isOverRest: Bool
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.unbound.bg)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * CGFloat(clamped))
                    .shadow(color: color.opacity(0.35), radius: 5)
                if isOverRest {
                    Capsule()
                        .strokeBorder(Color.unbound.warnOrange.opacity(0.7), lineWidth: 1)
                }
            }
        }
        .frame(height: 7)
        .accessibilityLabel("Rest guard")
    }
}

// MARK: - ExplainerPayload

struct ExplainerPayload: Identifiable, Equatable {
    let name: String
    let description: String?    // AI-supplied 1-line description, when present
    let cues: [String]?         // for helper rows we already have cues
    let notes: String?          // for prescriptions, we have the rx note
    var id: String { name }

    init(name: String, description: String? = nil, cues: [String]? = nil, notes: String? = nil) {
        self.name = name
        self.description = description
        self.cues = cues
        self.notes = notes
    }
}

// MARK: - ExerciseExplainerSheet

struct ExerciseExplainerSheet: View {
    let payload: ExplainerPayload
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("EXERCISE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(payload.name)
                    .font(.system(.title2).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let desc = payload.description ?? ExerciseExplainerLibrary.description(for: payload.name) {
                Text(desc)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let cues = payload.cues, !cues.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("FORM")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    ForEach(Array(cues.enumerated()), id: \.offset) { _, cue in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.unbound.accent.opacity(0.7))
                                .frame(width: 5, height: 5)
                                .padding(.top, 8)
                            Text(cue)
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let notes = payload.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NOTES")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(notes)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            UnboundButton(title: "Close", variant: .secondary) {
                onClose()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}

// MARK: - SetLoggerSheet
//
// Tightened editor for a single set. One vertical column — primary input,
// weight chips, RPE chips. No section eyebrows beyond the chips' own labels.

private struct SetLoggerSheet: View {
    let prescription: TrainingPrescription?
    let existing: LoggedSet?
    let onSave: (LoggedSet) -> Void
    let onCancel: () -> Void

    // Inputs
    @State private var reps: Int = 0
    @State private var weightKg: Double = 0
    @State private var rpe: Int = 0    // 0 = unspecified
    @State private var holdSeconds: Int = 0

    // Hold timer state
    @State private var isTimerRunning: Bool = false
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                setWindowHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        setCombatHeader
                        primaryInput
                        if !isHoldTarget {
                            weightInput
                        }
                        rpeInput
                        Spacer().frame(height: 96)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                UnboundButton(
                    title: existing == nil ? "Log set" : "Update set",
                    icon: "checkmark"
                ) {
                    stopTimer()
                    let logged = LoggedSet(
                        reps: reps,
                        holdSeconds: isHoldTarget ? holdSeconds : nil,
                        weightKg: weightKg > 0 ? weightKg : nil,
                        rpe: rpe > 0 ? rpe : nil
                    )
                    onSave(logged)
                }
                .accessibilityIdentifier("skillSession.logSet")

                Button {
                    stopTimer()
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(height: 28)
                }
                .buttonStyle(.plain)
            }
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
        .onAppear { hydrate() }
        .onDisappear { stopTimer() }
    }

    private var setWindowHeader: some View {
        HStack(spacing: 12) {
            Button {
                stopTimer()
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(existing == nil ? "LOG SET" : "EDIT SET")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
                Text(prescription?.exerciseName ?? "Training")
                    .font(Font.unbound.titleS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Color.unbound.bg
                .overlay(Rectangle().fill(Color.unbound.borderSubtle).frame(height: 0.5), alignment: .bottom)
        )
    }

    private var setCombatHeader: some View {
        let rest = prescription?.restSeconds ?? 90
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ROUND INPUT")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(prescription?.targetDescription.uppercased() ?? "LOG WHAT YOU HIT")
                        .font(Font.unbound.bodyLStrong)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(rest)s")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.coachCyan)
                        .monospacedDigit()
                    Text("REST GUARD")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            HStack(spacing: 8) {
                setStat(label: "INPUT", value: isHoldTarget ? "TIME" : "REPS")
                setStat(label: "LOAD", value: isHoldTarget ? "BW" : (weightKg > 0 ? formatKg(weightKg) : "BW"))
                setStat(label: "EFFORT", value: rpe == 0 ? "OPEN" : "RPE \(rpe)")
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.accent.opacity(0.16),
                                Color.unbound.coachCyan.opacity(0.07),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.24), lineWidth: 1)
        )
    }

    private func setStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Primary input — varies by target type

    @ViewBuilder
    private var primaryInput: some View {
        if let target = prescription?.target {
            switch target {
            case .hold:
                holdTimerInput
            case .amrap:
                repsInput(label: "REPS ACHIEVED")
            case .reps, .repsRange, .tempo:
                repsInput(label: "REPS")
            }
        } else {
            repsInput(label: "REPS")
        }
    }

    private var isHoldTarget: Bool {
        if case .hold = prescription?.target { return true }
        return false
    }

    private func repsInput(label: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            HStack(spacing: 24) {
                roundIconButton(icon: "minus") {
                    if reps > 0 { reps -= 1; UnboundHaptics.soft() }
                }
                Text("\(reps)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(minWidth: 96)
                roundIconButton(icon: "plus") {
                    reps += 1; UnboundHaptics.soft()
                }
            }

            if case .tempo(let r, let e, let h, let c) = prescription?.target {
                Text("Tempo \(e)-\(h)-\(c) for \(r) reps")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(roundedCard)
    }

    private var holdTimerInput: some View {
        let targetSeconds: Int = {
            if case .hold(let s) = prescription?.target { return s }
            return 30
        }()
        let progress: Double = targetSeconds > 0
            ? min(1.0, Double(holdSeconds) / Double(targetSeconds))
            : 0
        let met = holdSeconds >= targetSeconds && targetSeconds > 0

        return VStack(spacing: 16) {
            Text("HOLD")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            ZStack {
                Circle()
                    .stroke(Color.unbound.surfaceElevated, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        met ? Color.unbound.impact : Color.unbound.accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
                    .shadow(
                        color: (met ? Color.unbound.impact : Color.unbound.accent).opacity(0.45),
                        radius: 8
                    )

                VStack(spacing: 2) {
                    Text(formatTime(holdSeconds))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("/ \(targetSeconds)s")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .monospacedDigit()
                }
            }
            .frame(width: 180, height: 180)

            HStack(spacing: 12) {
                Button(action: toggleTimer) {
                    HStack(spacing: 8) {
                        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        Text(isTimerRunning ? "Pause" : "Start")
                    }
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
                    .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(.headline).weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                        .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(roundedCard)
    }

    private var weightInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WEIGHT (KG)")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(weightKg > 0 ? formatKg(weightKg) : "Bodyweight")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(weightKg > 0 ? Color.unbound.textPrimary : Color.unbound.textTertiary)
            }

            HStack(spacing: 8) {
                ForEach([0.0, 2.5, 5.0, 7.5, 10.0, 15.0, 20.0], id: \.self) { value in
                    Button {
                        weightKg = value
                        UnboundHaptics.soft()
                    } label: {
                        Text(value == 0 ? "BW" : "\(formatKg(value))")
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(weightKg == value ? Color.unbound.bg : Color.unbound.textSecondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(weightKg == value ? Color.unbound.accent : Color.unbound.surfaceElevated)
                            )
                            .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private var rpeInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RPE (EFFORT)")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(rpe == 0 ? "Optional" : "\(rpe) / 10")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(rpe == 0 ? Color.unbound.textTertiary : Color.unbound.textPrimary)
            }

            HStack(spacing: 6) {
                ForEach(1...10, id: \.self) { v in
                    Button {
                        rpe = (rpe == v) ? 0 : v
                        UnboundHaptics.soft()
                    } label: {
                        Text("\(v)")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .foregroundStyle(rpe == v ? Color.unbound.bg : Color.unbound.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(rpe == v ? Color.unbound.accent : Color.unbound.surfaceElevated))
                            .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    // MARK: - Hydration

    private func hydrate() {
        if let existing {
            reps = existing.reps
            weightKg = existing.weightKg ?? 0
            rpe = existing.rpe ?? 0
            holdSeconds = existing.holdSeconds ?? 0
            return
        }
        // Defaults from prescription target
        guard let target = prescription?.target else { return }
        switch target {
        case .reps(let n):
            reps = n
        case .repsRange(let lo, let hi):
            reps = (lo + hi) / 2
        case .amrap:
            reps = 0
        case .hold:
            holdSeconds = 0
        case .tempo(let r, _, _, _):
            reps = r
        }
    }

    // MARK: - Hold timer

    private func toggleTimer() {
        if isTimerRunning { stopTimer() } else { startTimer() }
    }

    private func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        UnboundHaptics.medium()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                holdSeconds += 1
            }
        }
    }

    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func resetTimer() {
        stopTimer()
        holdSeconds = 0
    }

    // MARK: - Helpers

    private func formatTime(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    private func formatKg(_ kg: Double) -> String {
        if kg == floor(kg) {
            return "\(Int(kg))kg"
        }
        return String(format: "%.1fkg", kg)
    }

    private func roundIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.unbound.surfaceElevated))
                .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var roundedCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        }
    }
}
