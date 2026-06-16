import SwiftUI
import UIKit

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

        if canClaimRoutineReward, completionResult.overallLevelXPEarnedBeforeDebt > 0 {
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
                ForEach(Array(routine.steps.enumerated()), id: \.offset) { index, step in
                    stepRow(index: index, step: step)
                        .padding(.vertical, 11)

                    if index < routine.steps.count - 1 {
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

    // Full detail: a circuit expands into its rounds + every move (no capping,
    // no "+N more"), so the plan reads completely before you start.
    @ViewBuilder
    private func stepRow(index: Int, step: RoutineStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(Font.unbound.monoS.weight(.heavy))
                .foregroundStyle(routine.category.color)
                .frame(width: 20, alignment: .trailing)
                .padding(.top, 1)

            if case let .circuit(rounds, rest, moves) = step {
                VStack(alignment: .leading, spacing: 7) {
                    Text(rest > 0 ? "Circuit × \(rounds) rounds · \(rest)s rest" : "Circuit × \(rounds) rounds")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)

                    ForEach(Array(moves.enumerated()), id: \.offset) { _, move in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(routine.category.color.opacity(0.7))
                                .frame(width: 4, height: 4)
                                .padding(.top, 7)
                            Text(routineStepPreview(move))
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text(routineStepPreview(step))
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
