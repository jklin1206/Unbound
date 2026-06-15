import SwiftUI
import UIKit

struct ProgramRoutinesTab: View {
    @Binding var selectedChallengeId: String
    @Binding var selectedRoutineIdsByCategory: [RoutineCategory: String]
    let currentTier: SkillTier
    let onBeginRoutine: (RoutineDef) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Enter a dungeon when today needs a different shape. Reach higher depths to open deeper floors.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                challengeLibrary

                ForEach(RoutineCategory.allCases.filter { $0 != .challenge }, id: \.self) { category in
                    routineSection(category: category)
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
                Text("DUNGEON BOARD")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(RoutineCategory.challenge.color)
                Spacer()
                Text("\(challenges.count) dungeons")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            TabView(selection: $selectedChallengeId) {
                ForEach(challenges) { routine in
                    let unlockState = RoutineUnlockPolicy.state(for: routine, currentTier: currentTier)
                    Button {
                        guard unlockState.isUnlocked else {
                            UnboundHaptics.soft()
                            return
                        }
                        onBeginRoutine(routine)
                    } label: {
                        RoutineChallengeCard(routine: routine, unlockState: unlockState)
                    }
                    .buttonStyle(RoutineChallengePressStyle())
                    .disabled(!unlockState.isUnlocked)
                    .tag(routine.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: RoutineDungeonLayout.cardHeight)

            RoutineChallengeDots(challenges: challenges, selectedId: selectedChallengeId)
        }
    }

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
                Text("\(items.count) dungeons")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            TabView(selection: selection) {
                ForEach(items) { routine in
                    let unlockState = RoutineUnlockPolicy.state(for: routine, currentTier: currentTier)
                    Button {
                        guard unlockState.isUnlocked else {
                            UnboundHaptics.soft()
                            return
                        }
                        onBeginRoutine(routine)
                    } label: {
                        RoutineChallengeCard(routine: routine, unlockState: unlockState)
                    }
                    .buttonStyle(RoutineChallengePressStyle())
                    .disabled(!unlockState.isUnlocked)
                    .tag(routine.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: RoutineDungeonLayout.cardHeight)

            RoutineChallengeDots(challenges: items, selectedId: selection.wrappedValue)
        }
    }
}

private enum RoutineDungeonLayout {
    static let cardHeight: CGFloat = 352
    static let fallbackCoverAspectRatio: CGFloat = 2688.0 / 1520.0
}

// MARK: - Routine step preview helper

private func routineStepPreview(_ step: RoutineStep) -> String {
    switch step {
    case .instruction(let t, _):            return t
    case .timed(let l, let s, _):           return "\(l) — \(s)s"
    case .interval(let l, let r, let segs):
        let work = segs.map { "\($0.label) \($0.seconds)s" }.joined(separator: " / ")
        return work.isEmpty ? "\(l) — \(r) rounds" : "\(l) — \(r) rounds: \(work)"
    case .repTarget(let n, let t, _):       return t.map { "\(n) — \($0)" } ?? "\(n) — AMRAP"
    case .circuit(let r, _, let steps):
        let moves = steps.compactMap(routineStepShortLabel).prefix(4).joined(separator: " + ")
        return moves.isEmpty ? "Circuit × \(r) rounds" : "Circuit × \(r): \(moves)"
    case .note(let t):                      return t
    }
}

private func routineRunStepPreview(_ runStep: RoutineRunStep) -> String {
    let preview = routineStepPreview(runStep.kind)
    guard let roundLabel = runStep.roundLabel else { return preview }
    return "\(roundLabel): \(preview)"
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
        .accessibilityLabel("\(tier.displayName) dungeon difficulty")
    }
}

struct RoutineChallengeCard: View {
    let routine: RoutineDef
    let unlockState: RoutineUnlockState

    private var canComplete: Bool {
        RoutineHistoryStore.shared.canComplete(routineId: routine.id)
    }

    private var coverAspectRatio: CGFloat {
        UIImage(named: routine.coverAssetName)?.routineCoverAspectRatio ?? RoutineDungeonLayout.fallbackCoverAspectRatio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                routineCover

                LinearGradient(
                    colors: [.clear, Color.unbound.bg.opacity(0.70), Color.unbound.bg.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 7) {
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
                .padding(.horizontal, 18)
                .padding(.vertical, 16)

                if !unlockState.isUnlocked {
                    lockedOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .aspectRatio(coverAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    metricPill(value: routine.durationLabel, label: "TIME")
                    depthMetricPill(tier: routine.difficultyTier)
                    unlockMetricPill
                }

                HStack(spacing: 10) {
                    Text(unlockState.isUnlocked ? routine.steps.first.map(routineStepPreview) ?? "Open the dungeon and start." : unlockState.requirementText)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Text(actionLabel)
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.4)
                        Image(systemName: actionIcon)
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.bg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(actionTint))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 15)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .saturation(unlockState.isUnlocked && canComplete ? 1 : 0.22)
                .opacity(unlockState.isUnlocked ? (canComplete ? 0.92 : 0.56) : 0.34)
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
                .fill(statusTint)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(Font.unbound.monoS.weight(.heavy))
                .tracking(1.3)
        }
        .foregroundStyle(statusTint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.unbound.bg.opacity(0.62)))
        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }

    private var lockedOverlay: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("SEALED")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.3)
            }
            Text(unlockState.lockedText.uppercased())
                .font(Font.unbound.monoS.weight(.bold))
                .tracking(0.8)
        }
        .foregroundStyle(Color.unbound.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.textTertiary.opacity(0.36), lineWidth: 1)
        )
        .padding(16)
    }

    private var statusText: String {
        if !unlockState.isUnlocked { return "SEALED" }
        return canComplete ? "DUNGEON READY" : "CLEARED TODAY"
    }

    private var statusTint: Color {
        if !unlockState.isUnlocked { return Color.unbound.textTertiary }
        return canComplete ? routine.category.color : Color.unbound.textTertiary
    }

    private var actionLabel: String {
        if !unlockState.isUnlocked { return "SEALED" }
        return canComplete ? "ENTER" : "OPEN"
    }

    private var actionIcon: String {
        if !unlockState.isUnlocked { return "lock.fill" }
        return canComplete ? "arrow.right" : "checkmark.seal.fill"
    }

    private var actionTint: Color {
        if !unlockState.isUnlocked { return Color.unbound.textTertiary }
        return canComplete ? routine.category.color : Color.unbound.textTertiary
    }

    private var unlockMetricPill: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(unlockState.isUnlocked ? "OPEN" : unlockState.requiredTier.displayName.uppercased())
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(unlockState.isUnlocked ? "DUNGEON" : "DEPTH")
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
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder((unlockState.isUnlocked ? routine.category.color : Color.unbound.textTertiary).opacity(0.22), lineWidth: 1)
        )
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

    private func depthMetricPill(tier: SkillTier) -> some View {
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

            Text("DEPTH")
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
        .accessibilityLabel("\(tier.displayName) dungeon depth")
    }
}

struct RoutineChallengeDots: View {
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

struct RoutineTravelOverlay: View {
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

                Text("ENTERING DUNGEON")
                    .font(Font.unbound.monoS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(routine.category.color)
            }
            .padding(.horizontal, 28)
        }
    }
}

struct RoutineChallengePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private extension RoutineDef {
    var coverAssetName: String { "routine_challenge_\(id)" }
}

private extension UIImage {
    var routineCoverAspectRatio: CGFloat {
        guard size.height > 0 else { return RoutineDungeonLayout.fallbackCoverAspectRatio }
        return size.width / size.height
    }
}

struct RoutineCompletionFlow: View {
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
        planRun.count
    }

    private var planRun: [RoutineRunStep] {
        RoutineRun.build(routine.steps).run
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

            Text("DUNGEON READY")
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
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .aspectRatio(image.routineCoverAspectRatio, contentMode: .fit)
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
            statPill(value: routine.difficultyTier.displayName.uppercased(), label: "DEPTH", icon: "shield.lefthalf.filled")
            statPill(value: "\(runCount)", label: "STEPS", icon: "list.bullet")
            statPill(value: canEarnLevelXP ? "PROOF" : "LOGGED", label: "LVL XP", icon: "sparkles")
        }
    }

    private var stepPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DUNGEON PLAN")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.7)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(planRun.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(Font.unbound.monoS.weight(.heavy))
                            .foregroundStyle(routine.category.color)
                            .frame(width: 20, alignment: .trailing)
                            .padding(.top, 1)

                        Text(routineRunStepPreview(step))
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 11)

                    if index < planRun.count - 1 {
                        Divider()
                            .background(Color.unbound.borderSubtle)
                            .padding(.leading, 32)
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
                    Text("START DUNGEON")
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

    private var planRun: [RoutineRunStep] {
        RoutineRun.build(routine.steps).run
    }

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
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(image.routineCoverAspectRatio, contentMode: .fit)
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

                    if !planRun.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("HOW TO DO IT")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(2.0)
                                .foregroundStyle(Color.unbound.textTertiary)
                                .padding(.bottom, 10)

                            ForEach(Array(planRun.enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(i + 1)")
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(routine.category.color)
                                        .frame(width: 20, alignment: .trailing)
                                        .padding(.top, 1)
                                    Text(routineRunStepPreview(step))
                                        .font(Font.unbound.bodyM)
                                        .foregroundStyle(Color.unbound.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 10)
                                if i < planRun.count - 1 {
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
