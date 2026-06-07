import SwiftUI
import UIKit

struct ProgramRankExerciseDetailView: View {
    let row: ProgramRankLibraryRow
    let onLogged: () async -> Void

    @EnvironmentObject private var services: ServiceContainer

    @State private var progress: MovementProgressState?
    @State private var userProfile: UserProfile?
    @State private var history: [ProgramRankExerciseHistoryEntry] = []
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var hasSeededDefaults = false

    @State private var selectedWeightDisplay: Double = 0
    @State private var selectedReps: Int = 1
    @State private var selectedSeconds: Int = 30
    @State private var selectedRepGraphRange: ProgramRankRepGraphRange = .thirtyDays
    @State private var rankReveal: ProgramRankAttemptReveal?

    private var definition: MovementDefinition? {
        MovementCatalog.definition(for: row.sourceId)
            ?? MovementCatalog.resolvedTrainingMovement(name: row.title)?.standard
    }

    private var logMode: ProgramRankExerciseLogMode {
        definition.map(ProgramRankExerciseLogMode.mode(for:)) ?? .oneRepMax
    }

    private var tint: Color {
        displayedTier.rewardTextTint
    }

    private var displayedTier: SkillTier {
        resolvedTier(for: progress) ?? row.tier
    }

    private var weightUnit: TrainingWeightUnit {
        WeightPlatePolicy.currentUnit
    }

    private var selectedWeightKg: Double? {
        guard selectedWeightDisplay > 0 else { return nil }
        return weightUnit.kilograms(fromDisplayValue: selectedWeightDisplay)
    }

    private var canSubmit: Bool {
        switch logMode {
        case .oneRepMax:
            return selectedWeightDisplay > 0
        case .reps:
            return selectedReps > 0
        case .hold:
            return selectedSeconds > 0
        }
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if let definition {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        hero(definition)
                        progressSummary
                        targetMapSection(definition)
                        guideLayer(definition)
                        singleLogCard(definition)
                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
                }
            } else {
                missingState
            }
        }
        .navigationTitle(definition?.displayName ?? row.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .alert("Couldn't save rank attempt", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Retry") { Task { await submitLog() } }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Your selections are still here.")
        }
        .toolbar(rankReveal == nil ? .visible : .hidden, for: .navigationBar)
        .overlay {
            if let rankReveal {
                ProgramRankAttemptRevealOverlay(reveal: rankReveal) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        self.rankReveal = nil
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }

    private func hero(_ definition: MovementDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            heroArtwork(definition)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.08, contentMode: .fit)

            VStack(alignment: .leading, spacing: 6) {
                Text(definition.displayName.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func heroArtwork(_ definition: MovementDefinition) -> some View {
        if let assetName = row.visualAssetName {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(heroArtworkBackground(for: assetName))

                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .scaleEffect(assetName.hasSuffix("_highlight") ? 1.18 : 1.0)
                    .padding(heroArtworkPadding(for: assetName))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityLabel("\(definition.displayName) visual")
        } else {
            ExerciseVisualView(definition: definition, size: .hero)
        }
    }

    private func heroArtworkBackground(for assetName: String) -> AnyShapeStyle {
        if shouldUseWhiteArtworkStage(for: assetName) {
            return AnyShapeStyle(Color.white)
        }
        if assetName.hasSuffix("_highlight") {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.36, green: 0.25, blue: 0.15),
                        Color(red: 0.18, green: 0.13, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.unbound.surfaceElevated.opacity(0.28))
    }

    private func shouldUseWhiteArtworkStage(for assetName: String) -> Bool {
        assetName.hasPrefix("exercise_visual_")
            && row.source == .exercise
            && !row.id.hasPrefix("movement-detail-")
    }

    private func heroArtworkPadding(for assetName: String) -> CGFloat {
        if assetName.hasPrefix("exercise_visual_") { return 6 }
        return assetName.hasSuffix("_highlight") ? 0 : 14
    }

    private var progressSummary: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(displayedTier.displayName.uppercased())
                .font(Font.unbound.titleS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            Text(bestSummary)
                .font(Font.unbound.bodyS.weight(.bold))
                .foregroundStyle(Color.unbound.coachCyan)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bestSummary: String {
        if let progress {
            return ProgramRankExerciseFormatter.bestSummary(progress)
        }
        return row.detail
    }

    private func targetMapSection(_ definition: MovementDefinition) -> some View {
        let targetRegions = ProgramRankTargetRegionSet.regions(for: definition)

        return detailSection(
            title: "TARGET MAP",
            subtitle: targetRegions.isEmpty ? "No catalog body regions for this standard" : nil
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgramRankTargetBodyFigure(
                        side: .front,
                        targetRegions: targetRegions,
                        tint: tint
                    )
                    ProgramRankTargetBodyFigure(
                        side: .back,
                        targetRegions: targetRegions,
                        tint: tint
                    )
                }

                ProgramRankTargetRegionStrip(
                    regions: targetRegions,
                    tint: tint
                )
            }
        }
    }

    private func singleLogCard(_ definition: MovementDefinition) -> some View {
        detailSection(title: "LOG A SET") {
            VStack(alignment: .leading, spacing: 14) {
                switch logMode {
                case .oneRepMax:
                    oneRepMaxRail(definition)
                    proofHistoryGraph
                case .reps:
                    repsRail(limit: 80)
                    proofHistoryGraph
                case .hold:
                    secondsRail(title: "Hold Time")
                    proofHistoryGraph
                }

                rankLogActionButton
            }
        }
    }

    private var rankLogActionButton: some View {
        let isEnabled = canSubmit && !isSubmitting

        return Button {
            guard isEnabled else { return }
            UnboundHaptics.medium()
            Task { await submitLog() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSubmitting ? "hourglass" : "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text(isSubmitting ? "Saving Attempt" : "Reveal Rank")
                    .font(Font.unbound.bodyLStrong)
                    .tracking(0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    Color.unbound.surfaceElevated
                    Rectangle().fill(.thinMaterial).opacity(0.18)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isEnabled ? tint.opacity(0.72) : Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(isEnabled ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("program.rankExerciseDetail.logResult")
    }

    private var proofHistoryGraph: some View {
        ProgramRankProofHistoryLineGraph(
            entries: history,
            currentValue: currentProofGraphValue,
            historyValue: proofGraphValue(for:),
            valueFormatter: proofGraphValueText(_:),
            selectedRange: $selectedRepGraphRange,
            tint: tint,
            accessibilityUnit: logMode.accessibilityUnit
        )
    }

    private var currentProofGraphValue: Double {
        switch logMode {
        case .oneRepMax:
            return max(selectedWeightDisplay, 0)
        case .reps:
            return Double(max(selectedReps, 1))
        case .hold:
            return Double(max(selectedSeconds, 1))
        }
    }

    private func proofGraphValue(for entry: ProgramRankExerciseHistoryEntry) -> Double? {
        switch logMode {
        case .oneRepMax:
            guard let oneRepMaxKg = entry.oneRepMaxKg else { return nil }
            return weightUnit.displayValue(fromKilograms: oneRepMaxKg)
        case .reps:
            return entry.reps.map(Double.init)
        case .hold:
            return entry.holdSeconds.map(Double.init)
        }
    }

    private func proofGraphValueText(_ value: Double) -> String {
        switch logMode {
        case .oneRepMax:
            return "\(WeightPlatePolicy.formatDisplayValue(value))\(weightUnit.shortLabel)"
        case .reps:
            return "\(Int(value.rounded()))"
        case .hold:
            return ProgramRankExerciseFormatter.seconds(Int(value.rounded()))
        }
    }

    @ViewBuilder
    private func guideLayer(_ definition: MovementDefinition) -> some View {
        if let skillForm = skillFormGuide(for: definition) {
            detailSection(title: "SKILL FORM") {
                FormPhaseSlideshow(
                    phases: skillForm.phases,
                    skillTitle: skillForm.title
                )
            }
        } else {
            SkillGuideLayerView(
                layer: .rankExercise(definition: definition),
                tint: tint,
                isProminent: true
            )
        }
    }

    private func skillFormGuide(for definition: MovementDefinition) -> (title: String, phases: [FormPhase])? {
        guard let skillId = definition.skillId else { return nil }
        let node = SkillGraph.shared.node(id: skillId)
        let phases = FormPhaseLibrary.phases(
            for: skillId,
            fallbackTitle: node?.title ?? definition.displayName,
            formCues: node?.formCues ?? []
        )
        guard !phases.isEmpty else { return nil }
        return (node?.title ?? definition.displayName, phases)
    }

    private var historyCard: some View {
        detailSection(title: "PAST HISTORY", subtitle: "Recent attempts for this rank standard") {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.unbound.accent)
                    Text("Loading history")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if history.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("No attempts yet. Reveal one result and it will appear here.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(history) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
    }

    private var missingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.diamond")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Movement not found")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("This rank standard no longer maps to a catalog exercise.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }

    private func summaryTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(cardBackground(cornerRadius: 12, tint: tint.opacity(0.16)))
    }

    private func oneRepMaxRail(_ definition: MovementDefinition) -> some View {
        let config = weightRulerConfig(allowsBodyweight: definition.rankTemplate == .weightedBodyweight)
        let tick = Binding<Int>(
            get: { config.tick(for: selectedWeightDisplay) },
            set: { selectedWeightDisplay = config.value(for: $0) }
        )
        let isAddedLoad = definition.rankTemplate == .weightedBodyweight
        let title = isAddedLoad ? "Added 1RM" : "1RM"
        let value = isAddedLoad ? addedLoadSummary : formatDisplayWeight(selectedWeightDisplay)

        return ProgramRankMetricRuler(
            title: title,
            valueText: value,
            range: config.range,
            value: tick,
            format: { config.formatValue($0, using: weightUnit, isAddedLoad: isAddedLoad) },
            tickLabel: { config.tickLabel($0) },
            majorEvery: config.majorEvery,
            tickSpacing: 13
        )
    }

    private func repsRail(limit: Int) -> some View {
        ProgramRankMetricRuler(
            title: "Reps",
            valueText: "\(selectedReps)",
            range: 1...limit,
            value: $selectedReps,
            unitLabel: "REPS",
            format: { "\($0)" },
            tickLabel: { "\($0)" },
            majorEvery: limit > 40 ? 10 : 5,
            tickSpacing: 15
        )
    }

    private func secondsRail(title: String) -> some View {
        let step = 5
        let maxTick = 1_200 / step
        let tick = Binding<Int>(
            get: { min(max(Int((Double(selectedSeconds) / Double(step)).rounded()), 1), maxTick) },
            set: { selectedSeconds = max(1, min($0, maxTick)) * step }
        )
        let majorEvery = title == "Hold Time" ? 6 : 12

        return ProgramRankMetricRuler(
            title: title,
            valueText: ProgramRankExerciseFormatter.seconds(selectedSeconds),
            range: 1...maxTick,
            value: tick,
            format: { ProgramRankExerciseFormatter.seconds($0 * step) },
            tickLabel: { ProgramRankExerciseFormatter.seconds($0 * step) },
            majorEvery: majorEvery,
            tickSpacing: 12
        )
    }

    private var addedLoadSummary: String {
        selectedWeightDisplay > 0 ? "+\(formatDisplayWeight(selectedWeightDisplay))" : "Bodyweight only"
    }

    private func detailSection<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Font.unbound.bodyS.weight(.heavy))
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardBackground(cornerRadius: CGFloat, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(tint, lineWidth: 1)
        }
    }

    private func historyRow(_ entry: ProgramRankExerciseHistoryEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.summary)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(entry.dateText)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    @MainActor
    private func loadDetail() async {
        guard let userId = services.auth.currentUserId else {
            isLoading = false
            return
        }

        isLoading = true
        async let progressLoad: [MovementProgressState] = services.database.query(
            collection: "movement_progress",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: true,
            limit: nil
        )
        async let logLoad: [PerformanceLog] = services.database.query(
            collection: "performanceLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "completedAt",
            descending: true,
            limit: 80
        )
        async let profileLoad: UserProfile? = services.database.read(
            collection: "users",
            documentId: userId
        )

        let progressStates = (try? await progressLoad) ?? []
        let logs = (try? await logLoad) ?? []
        userProfile = try? await profileLoad
        progress = progressStates.first { $0.rankStandardMovementId == row.sourceId }
        history = ProgramRankExerciseHistoryEntry.entries(
            from: logs,
            rankStandardMovementId: row.sourceId
        )

        if !hasSeededDefaults {
            seedDefaults(from: progress)
            hasSeededDefaults = true
        }
        isLoading = false
    }

    @MainActor
    private func submitLog() async {
        guard !isSubmitting else { return }
        guard let definition else {
            errorMessage = "This rank standard is missing from the movement catalog."
            return
        }
        guard let userId = services.auth.currentUserId else {
            errorMessage = "Sign in before saving a rank attempt."
            return
        }

        isSubmitting = true
        errorMessage = nil

        let now = Date()
        let performanceLog = makePerformanceLog(definition: definition, userId: userId, completedAt: now)
        let priorTier = displayedTier

        do {
            let result = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
            let reveal = makeRankReveal(
                from: result,
                definition: definition,
                priorTier: priorTier
            )
            await loadDetail()
            await onLogged()
            if reveal.isRankUp {
                HapticManager.notification(.success)
            } else {
                UnboundHaptics.medium()
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                rankReveal = reveal
            }
        } catch {
            HapticManager.notification(.error)
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func makePerformanceLog(
        definition: MovementDefinition,
        userId: String,
        completedAt: Date
    ) -> PerformanceLog {
        let set = PerformanceSet(
            setNumber: 1,
            reps: logMode.recordsReps ? selectedReps : logMode.recordsOneRepMax ? 1 : nil,
            weightKg: logMode.recordsOneRepMax ? selectedWeightKg : nil,
            holdSeconds: logMode == .hold ? selectedSeconds : nil,
            durationSeconds: nil,
            distanceMeters: nil,
            calories: nil,
            rpe: nil,
            qualityFlags: [],
            notes: nil
        )
        let exercise = PerformanceExercise(
            name: definition.displayName,
            movementId: definition.id,
            rankStandardMovementId: definition.rankStandardMovementId,
            plannedSets: 1,
            plannedTarget: logSummary,
            sets: [set],
            notes: nil
        )
        let block = PerformanceBlock(
            kind: definition.blockKind,
            title: definition.displayName,
            exercises: [exercise],
            durationSeconds: nil,
            distanceMeters: nil,
            calories: nil,
            notes: "Single rank attempt"
        )

        return PerformanceLog(
            id: "rank-log-\(UUID().uuidString)",
            userId: userId,
            source: .custom,
            title: "\(definition.displayName) Rank Attempt",
            startedAt: completedAt,
            completedAt: completedAt,
            blocks: [block],
            overallRPE: nil,
            notes: nil
        )
    }

    private func makeRankReveal(
        from result: TrainingCompletionResult,
        definition: MovementDefinition,
        priorTier: SkillTier
    ) -> ProgramRankAttemptReveal {
        let standardId = definition.rankStandardMovementId
        let updatedProgress = result.movementProgressStates.first {
            $0.rankStandardMovementId == standardId
        }
        let previousTier = resolvedTier(for: result.movementProgressPriorStates[standardId]) ?? priorTier
        let achievedTier = resolvedTier(for: updatedProgress)
            ?? resolvedTier(for: result.movementProgressPriorStates[standardId])
            ?? priorTier

        return ProgramRankAttemptReveal(
            attemptSummary: logSummary,
            tier: achievedTier,
            previousTier: previousTier
        )
    }

    private func resolvedTier(for state: MovementProgressState?) -> SkillTier? {
        guard let state else { return nil }
        return MovementProgressTierResolver.provenTier(
            for: state,
            bodyweightKg: userProfile?.weightKg,
            sex: userProfile?.biologicalSex
        )
    }

    private var logSummary: String {
        switch logMode {
        case .oneRepMax:
            if definition?.rankTemplate == .weightedBodyweight {
                return "Added 1RM \(addedLoadSummary)"
            }
            return "1RM \(formatDisplayWeight(selectedWeightDisplay))"
        case .reps:
            return "\(selectedReps) reps"
        case .hold:
            return "\(ProgramRankExerciseFormatter.seconds(selectedSeconds)) hold"
        }
    }

    private func seedDefaults(from progress: MovementProgressState?) {
        selectedReps = max(1, progress?.bestReps ?? 10)
        switch logMode {
        case .oneRepMax:
            if let oneRepMax = progress?.bestEstimatedOneRepMaxKg ?? progress?.bestLoadKg {
                selectedWeightDisplay = WeightPlatePolicy.editingValue(fromKilograms: oneRepMax, unit: weightUnit)
            } else {
                selectedWeightDisplay = defaultWeightDisplay
            }
        case .reps, .hold:
            selectedWeightDisplay = 0
        }
        selectedSeconds = progress?.bestHoldSeconds
            ?? progress?.bestDurationSeconds
            ?? defaultSeconds
    }

    private var defaultWeightDisplay: Double {
        guard logMode == .oneRepMax else { return 0 }
        if definition?.rankTemplate == .weightedBodyweight { return 0 }
        return weightUnit == .pounds ? 135 : 60
    }

    private var defaultSeconds: Int {
        switch logMode {
        case .hold: return 30
        default: return 30
        }
    }

    private func weightRulerConfig(allowsBodyweight: Bool) -> ProgramRankWeightRulerConfig {
        let step = WeightPlatePolicy.loadIncrement(unit: weightUnit)
        let majorIncrement: Double = weightUnit == .pounds ? 25 : 10
        let start: Double
        let baseEnd: Double

        if definition?.rankTemplate == .weightedBodyweight {
            start = allowsBodyweight ? 0 : step
            baseEnd = weightUnit == .pounds ? 300 : 140
        } else {
            start = weightUnit == .pounds ? 45 : 20
            baseEnd = weightUnit == .pounds ? 1_000 : 450
        }
        let selectedEnd = selectedWeightDisplay > 0
            ? (ceil((selectedWeightDisplay + majorIncrement * 2) / majorIncrement) * majorIncrement)
            : baseEnd
        let end = max(baseEnd, selectedEnd)

        return ProgramRankWeightRulerConfig(
            start: start,
            end: end,
            step: step,
            majorDisplayIncrement: majorIncrement
        )
    }

    private func formatDisplayWeight(_ value: Double) -> String {
        "\(WeightPlatePolicy.formatDisplayValue(value))\(weightUnit.shortLabel)"
    }
}
