import SwiftUI

// MARK: - QuickLogSheet
//
// Lightweight "I did some reps" capture path. Used when the user just wants
// to log a single set (e.g., "8 pull-ups in the gym") without launching a
// structured session. Awards 10 XP — smaller than a full session — and the
// 24h cap still gates it via SkillProgressService.canTrain on the parent.

struct QuickLogSheet: View {
    let skillId: String
    let skillTitle: String
    let defaultReps: Int
    var isHoldBased: Bool = false
    var holdTargetSeconds: Int = 30

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: ServiceContainer

    @State private var reps: Int = 0
    @State private var holdSeconds: Int = 0
    @State private var weightKg: Double = 0
    @State private var rpe: Int = 0
    @State private var qualityFlags: Set<PerformanceQualityFlag> = [.clean]
    @State private var setNotes: String = ""
    @State private var isSubmitting: Bool = false
    @State private var submitErrorMessage: String? = nil
    @State private var isTimerRunning: Bool = false
    @State private var holdTimer: Timer?
    @State private var rewardSequence: WorkoutRewardSequenceSummary? = nil
    @State private var presentationDetent: PresentationDetent = .medium
    @State private var pendingCompletionLogId: String? = nil
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    private static let quickLogXP: Int = 10

    init(
        skillId: String,
        skillTitle: String,
        defaultReps: Int,
        isHoldBased: Bool = false,
        holdTargetSeconds: Int = 30
    ) {
        self.skillId = skillId
        self.skillTitle = skillTitle
        self.defaultReps = defaultReps
        self.isHoldBased = isHoldBased
        self.holdTargetSeconds = holdTargetSeconds
    }

    var body: some View {
        quickLogForm
        .presentationDetents([.medium, .large], selection: $presentationDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
        .fullScreenCover(item: $rewardSequence) { sequence in
            WorkoutRewardSequenceView(summary: sequence) {
                rewardSequence = nil
                dismiss()
            }
            .interactiveDismissDisabled(true)
        }
        .onDisappear { stopTimer() }
        .alert("Couldn't save set", isPresented: Binding(
            get: { submitErrorMessage != nil },
            set: { if !$0 { submitErrorMessage = nil } }
        )) {
            Button("Retry") { Task { await submit() } }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(submitErrorMessage ?? "Your set is still here. Try again when the connection is stable.")
        }
    }

    private var quickLogForm: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("QUICK LOG")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Text(skillTitle)
                    .font(.system(.title3).weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Log one set. \(QuickLogSheet.quickLogXP) XP.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 12) {
                    if isHoldBased {
                        holdCard
                        weightCard
                    } else {
                        repsCard
                        weightCard
                    }
                    rpeCard
                    qualityCard
                    notesCard
                }
                .padding(.horizontal, 4)
            }

            UnboundButton(
                title: isSubmitting ? "Saving Set" : "Log Set",
                icon: "checkmark",
                isEnabled: canSubmit && !isSubmitting
            ) {
                Task { await submit() }
            }
            .accessibilityIdentifier("skillQuickLog.submit")

            Button("Cancel") {
                stopTimer()
                dismiss()
            }
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textTertiary)
                .accessibilityIdentifier("skillQuickLog.cancel")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg.ignoresSafeArea())
        .onAppear {
            if !isHoldBased, reps == 0 { reps = defaultReps }
        }
    }

    private var canSubmit: Bool {
        isHoldBased ? holdSeconds > 0 : reps > 0
    }

    // MARK: - Hold (timer) card

    private var holdCard: some View {
        let progress: Double = holdTargetSeconds > 0
            ? min(1.0, Double(holdSeconds) / Double(holdTargetSeconds))
            : 0
        let met = holdSeconds >= holdTargetSeconds && holdTargetSeconds > 0

        return VStack(spacing: 14) {
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

                VStack(spacing: 2) {
                    Text(formatHold(holdSeconds))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("/ \(holdTargetSeconds)s")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .monospacedDigit()
                }
            }
            .frame(width: 160, height: 160)

            HStack(spacing: 12) {
                Button {
                    toggleTimer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        Text(isTimerRunning ? "Pause" : "Start")
                    }
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)

                Button {
                    stopTimer()
                    holdSeconds = 0
                    UnboundHaptics.soft()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(.headline).weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(roundedCard)
    }

    private func toggleTimer() {
        if isTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
        UnboundHaptics.medium()
    }

    private func startTimer() {
        isTimerRunning = true
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                holdSeconds += 1
            }
        }
    }

    private func stopTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        isTimerRunning = false
    }

    private func formatHold(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    // MARK: - Cards

    private var repsCard: some View {
        VStack(spacing: 6) {
            Text("REPS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            HStack(spacing: 24) {
                roundIconButton(icon: "minus") {
                    if reps > 0 { reps -= 1; UnboundHaptics.soft() }
                }
                Text("\(reps)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(minWidth: 90)
                roundIconButton(icon: "plus") {
                    reps += 1; UnboundHaptics.soft()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(roundedCard)
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WEIGHT (\(weightUnit.shortLabel.uppercased()))")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(weightKg > 0 ? formatWeight(weightKg) : "Bodyweight")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(weightKg > 0 ? Color.unbound.textPrimary : Color.unbound.textTertiary)
            }

            HStack(spacing: 6) {
                ForEach(weightChipValues, id: \.self) { value in
                    let chipWeightKg = kilograms(fromDisplayValue: value)
                    let isSelected = isSelectedWeightChip(chipWeightKg)
                    Button {
                        weightKg = chipWeightKg
                        UnboundHaptics.soft()
                    } label: {
                        Text(value == 0 ? "BW" : WeightPlatePolicy.formatLoggedWeightWithUnit(chipWeightKg, unit: weightUnit))
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.unbound.bg : Color.unbound.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(isSelected ? Color.unbound.accent : Color.unbound.surfaceElevated)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private var rpeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RPE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(rpe == 0 ? "Optional" : "\(rpe) / 10")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(rpe == 0 ? Color.unbound.textTertiary : Color.unbound.textPrimary)
            }

            HStack(spacing: 6) {
                ForEach([5, 6, 7, 8, 9, 10], id: \.self) { v in
                    Button {
                        rpe = (rpe == v) ? 0 : v
                        UnboundHaptics.soft()
                    } label: {
                        Text("\(v)")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .foregroundStyle(rpe == v ? Color.unbound.bg : Color.unbound.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(rpe == v ? Color.unbound.accent : Color.unbound.surfaceElevated))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private var qualityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("QUALITY")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text(qualityStatLabel)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(qualityHasWarning ? Color.unbound.alert : Color.unbound.textPrimary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                qualityChip(.clean, label: "Clean", icon: "checkmark.seal.fill")
                qualityChip(.assisted, label: "Assisted", icon: "lifepreserver.fill")
                qualityChip(.formBreak, label: "Form", icon: "exclamationmark.triangle.fill")
                qualityChip(.partialRange, label: "Partial", icon: "arrow.left.and.right")
                qualityChip(.pain, label: "Pain", icon: "heart.slash.fill")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)

            TextField("Band, wall, finger assist...", text: $setNotes, axis: .vertical)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2...4)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.bg.opacity(0.72))
                )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCard)
    }

    private func qualityChip(
        _ flag: PerformanceQualityFlag,
        label: String,
        icon: String
    ) -> some View {
        let isOn = qualityFlags.contains(flag)
        let color = qualityWarningFlags.contains(flag) ? Color.unbound.alert : Color.unbound.accent
        return Button {
            toggleQuality(flag)
            UnboundHaptics.soft()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isOn ? Color.unbound.bg : Color.unbound.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Capsule().fill(isOn ? color : Color.unbound.surfaceElevated))
        }
        .buttonStyle(.plain)
    }

    private var qualityProofBlockingFlags: Set<PerformanceQualityFlag> {
        [.assisted, .formBreak, .partialRange, .pain]
    }

    private var qualityWarningFlags: Set<PerformanceQualityFlag> {
        [.formBreak, .partialRange, .pain]
    }

    private var qualityHasWarning: Bool {
        !qualityFlags.intersection(qualityWarningFlags).isEmpty
    }

    private var qualityStatLabel: String {
        if qualityHasWarning { return "Review" }
        if qualityFlags.contains(.assisted) { return "Assisted" }
        return "Clean"
    }

    private var trimmedSetNotes: String? {
        setNotes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private func toggleQuality(_ flag: PerformanceQualityFlag) {
        if qualityFlags.contains(flag) {
            qualityFlags.remove(flag)
            if qualityFlags.isEmpty {
                qualityFlags.insert(.clean)
            }
            return
        }

        qualityFlags.insert(flag)
        if flag == .clean {
            qualityFlags.subtract(qualityProofBlockingFlags)
        } else if qualityProofBlockingFlags.contains(flag) {
            qualityFlags.remove(.clean)
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        submitErrorMessage = nil
        stopTimer()

        let now = Date()
        guard let userId = AuthService.shared.currentUserId else {
            isSubmitting = false
            submitErrorMessage = "Sign in before logging skill work."
            HapticManager.notification(.error)
            return
        }
        let set = LoggedSet(
            reps: isHoldBased ? 0 : reps,
            holdSeconds: isHoldBased ? holdSeconds : nil,
            weightKg: weightKg > 0 ? weightKg : nil,
            rpe: rpe > 0 ? rpe : nil,
            qualityFlags: qualityFlags,
            notes: trimmedSetNotes
        )

        // Snapshot user state BEFORE the write so RewardComputer can
        // diff for PRs, rank-ups, badges, and first-set detection.
        let preSnapshot = await RewardComputer.shared.before(
            skillId: skillId,
            isHoldBased: isHoldBased,
            userId: userId,
            badgeService: services.badges
        )
        let loggedExercises = [LoggedExercise(name: skillTitle, sets: [set])]
        let completionLogId = pendingCompletionLogId ?? UUID().uuidString
        pendingCompletionLogId = completionLogId

        let performanceLog = TrainingSessionAdapters.performanceLogForSkillSession(
            id: completionLogId,
            userId: userId,
            skillId: skillId,
            skillTitle: skillTitle,
            startedAt: now,
            completedAt: now,
            durationSeconds: 0,
            exercises: loggedExercises
        )

        let completionResult: TrainingCompletionResult
        do {
            completionResult = try await TrainingCompletionService.shared.complete(
                performanceLog,
                services: services,
                skillXPAwarded: QuickLogSheet.quickLogXP
            )
        } catch {
            isSubmitting = false
            submitErrorMessage = error.localizedDescription
            HapticManager.notification(.error)
            return
        }

        // Fan out to BadgeService so per-set unlocks fire. Returns the
        // newly-unlocked badges; the computer filters out anything that
        // was already unlocked at snapshot time.
        let triggerKey = isHoldBased ? "\(skillId).hold" : skillId
        let triggerReps = isHoldBased ? (set.holdSeconds ?? 0) : set.reps
        let unlocked = await services.badges.evaluate(
            trigger: .setCompleted(exerciseKey: triggerKey, reps: triggerReps)
        )

        var summary = await RewardComputer.shared.after(
            snapshot: preSnapshot,
            skillTitle: skillTitle,
            bestSet: set,
            xpGained: completionResult.skillXPGained,
            unlockedBadges: unlocked
        )
        summary.progression = completionResult.progressionReceipt

        UnboundHaptics.medium()

        isSubmitting = false
        pendingCompletionLogId = nil
        presentationDetent = .large
        rewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            rewardSummary: summary,
            fallbackXP: QuickLogSheet.quickLogXP,
            sourceName: "Quick Log"
        )
    }

    // MARK: - Helpers

    private var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    private var weightChipValues: [Double] {
        switch weightUnit {
        case .kilograms:
            return [0.0, 2.5, 5.0, 7.5, 10.0, 15.0, 20.0, 25.0]
        case .pounds:
            return [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 35.0, 45.0, 55.0]
        }
    }

    private func kilograms(fromDisplayValue value: Double) -> Double {
        value > 0 ? WeightPlatePolicy.kilograms(fromDisplayValue: value, unit: weightUnit) : 0
    }

    private func isSelectedWeightChip(_ kilograms: Double) -> Bool {
        abs(weightKg - kilograms) < 0.01
    }

    private func formatWeight(_ kg: Double) -> String {
        WeightPlatePolicy.formatLoggedWeightWithUnit(kg, unit: weightUnit)
    }

    private func roundIconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.unbound.surfaceElevated))
        }
        .buttonStyle(.plain)
    }

    // Calm: fill-only section panel — no border-on-fill double chrome.
    private var roundedCard: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.unbound.surface)
    }
}
