import SwiftUI

/// Rank tab of the unified rank detail — a clean showcase of WHERE YOU ARE NOW.
/// The current-rank emblem is the centerpiece; below it sits a single "GET YOUR
/// RANK" action. No ladder, no requirements: you demonstrate a feat to earn a
/// rank, and the rank-up reveals afterward — the climb and what-it-takes are
/// deliberately not shown here.
///
/// Everything ranks on the SAME inline ruler: exercises by reps / hold / 1RM
/// (strength standard); skills by reps, a timed hold, or — for weighted skills —
/// the added-load weight ruler, all through the single-source skill-ranking path
/// (never a session sheet, never bolted onto a strength ladder). A successful
/// log pulses the emblem and shows a brief RANK UP banner.
struct RankDetailRankTab: View {
    let vm: RankDetailViewModel
    var onLogged: (() async -> Void)?
    @EnvironmentObject private var services: ServiceContainer

    // Presentation-only state.
    @State private var errorMessage: String?

    // Each attempt reveals the rank THAT effort earned — a repeatable, blind,
    // graded test. The reveal is full-screen and dismissible, so you go again.
    @State private var attemptReveal: ProgramRankAttemptReveal?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            rankShowcase

            logSetSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("Couldn't save rank attempt", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Retry") { Task { await submit() } }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Your selections are still here.")
        }
        .fullScreenCover(item: $attemptReveal) { reveal in
            ProgramRankAttemptRevealOverlay(reveal: reveal) {
                attemptReveal = nil
            }
        }
    }

    // MARK: - 1. Rank showcase (the centerpiece)

    private var rankShowcase: some View {
        let hidden = vm.row?.isRankHidden ?? false
        return VStack(spacing: 14) {
            Text("CURRENT RANK")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)

            Image(vm.displayedTier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 124, height: 124)
                .opacity(hidden ? 0.4 : 1)
                .shadow(
                    color: hidden ? .clear : vm.tint.opacity(0.5),
                    radius: 18
                )

            Text(hidden ? "Unranked" : vm.displayedTier.displayName.uppercased())
                .font(Font.unbound.titleL.weight(.black))
                .foregroundStyle(hidden ? Color.unbound.textTertiary : vm.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - 2. Log a Set

    @ViewBuilder
    private var logSetSection: some View {
        if vm.loggingIsRulerBased, let definition = vm.movementDefinition {
            logSection(title: "GET YOUR RANK") {
                VStack(alignment: .leading, spacing: 14) {
                    metricRail(definition)
                    rulerSubmitButton
                }
            }
        } else if vm.skillNode != nil {
            // Skills rank on the SAME inline ruler as exercises — reps, a timed
            // hold, or an added-load weight. No sheet, no extra fields.
            logSection(title: "GET YOUR RANK") {
                VStack(alignment: .leading, spacing: 14) {
                    skillMetricRail
                    rulerSubmitButton
                }
            }
        }
    }

    @ViewBuilder
    private func metricRail(_ definition: MovementDefinition) -> some View {
        switch vm.logMode {
        case .oneRepMax:
            oneRepMaxRail(definition)
        case .reps:
            repsRail
        case .hold:
            secondsRail
        }
    }

    /// Skills rank on the same rails as exercises: reps, a timed hold, or — for
    /// weighted skills (weighted pull-up, …) — the added-load weight ruler.
    @ViewBuilder
    private var skillMetricRail: some View {
        switch vm.logMode {
        case .oneRepMax:
            if let definition = vm.movementDefinition {
                oneRepMaxRail(definition)
            }
        case .hold:
            secondsRail
        case .reps:
            repsRail
        }
    }

    private var repsRail: some View {
        ProgramRankMetricRuler(
            title: "Reps",
            valueText: "\(vm.selectedReps)",
            range: 1...80,
            value: Binding(get: { vm.selectedReps }, set: { vm.selectedReps = $0 }),
            unitLabel: "REPS",
            format: { "\($0)" },
            tickLabel: { "\($0)" },
            majorEvery: 10,
            tickSpacing: 15
        )
    }

    private func oneRepMaxRail(_ definition: MovementDefinition) -> some View {
        let isAddedLoad = definition.rankTemplate == .weightedBodyweight
        let config = vm.weightRulerConfig(allowsBodyweight: isAddedLoad)
        let tick = Binding<Int>(
            get: { config.tick(for: vm.selectedWeightDisplay) },
            set: { vm.selectedWeightDisplay = config.value(for: $0) }
        )
        let title = isAddedLoad ? "Added 1RM" : "1RM"
        let value = isAddedLoad ? vm.addedLoadSummary : vm.formatDisplayWeight(vm.selectedWeightDisplay)

        return ProgramRankMetricRuler(
            title: title,
            valueText: value,
            range: config.range,
            value: tick,
            format: { config.formatValue($0, using: vm.weightUnit, isAddedLoad: isAddedLoad) },
            tickLabel: { config.tickLabel($0) },
            majorEvery: config.majorEvery,
            tickSpacing: 13
        )
    }

    private var secondsRail: some View {
        // 1-second granularity from 1s. Hold tiers are generated as arbitrary
        // integers starting at 1s (1, 2, 3, 4, 6, 9…), so a coarse 5s step starting
        // at 5 made the early/odd thresholds literally unreachable — and now that
        // every attempt is graded on the exact value, the ruler must hit them.
        let maxSeconds = 300
        let value = Binding<Int>(
            get: { min(max(vm.selectedSeconds, 1), maxSeconds) },
            set: { vm.selectedSeconds = min(max($0, 1), maxSeconds) }
        )
        return ProgramRankMetricRuler(
            title: "Hold Time",
            valueText: ProgramRankExerciseFormatter.seconds(vm.selectedSeconds),
            range: 1...maxSeconds,
            value: value,
            format: { ProgramRankExerciseFormatter.seconds($0) },
            tickLabel: { ProgramRankExerciseFormatter.seconds($0) },
            majorEvery: 10,
            tickSpacing: 12
        )
    }

    private var rulerSubmitButton: some View {
        let isEnabled = vm.canSubmitRuler && !vm.isSubmitting
        return Button {
            guard isEnabled else { return }
            UnboundHaptics.medium()
            Task { await submit() }
        } label: {
            actionLabel(
                icon: vm.isSubmitting ? "hourglass" : "rosette",
                title: vm.isSubmitting ? "Saving" : "Get Your Rank",
                borderTint: isEnabled ? vm.tint.opacity(0.72) : Color.unbound.border
            )
            .opacity(isEnabled ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("rankDetail.rank.logResult")
    }

    // MARK: - Submit + per-attempt reveal

    private func submit() async {
        do {
            // Every attempt grades the effort just entered (independent of your
            // sticky best) and reveals the rank it earned — so you can log over
            // and over and see a different rank each time.
            let reveal = vm.loggingIsRulerBased
                ? try await vm.submitLog(services: services)
                : try await vm.submitSkillLog(services: services)
            if let reveal {
                await onLogged?()
                if reveal.isRankUp {
                    UnboundHaptics.success()
                } else {
                    UnboundHaptics.soft()
                }
                attemptReveal = reveal
            }
        } catch {
            HapticManager.notification(.error)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Shared styling

    private func logSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(Font.unbound.bodyS.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(Color.unbound.textTertiary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionLabel(icon: String, title: String, borderTint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(Font.unbound.bodyLStrong)
                .tracking(0.2)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(Color.unbound.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color.unbound.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(borderTint, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 14, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
