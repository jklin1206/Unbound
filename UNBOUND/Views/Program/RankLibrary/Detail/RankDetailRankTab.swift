import SwiftUI

/// Rank tab of the unified rank detail — a clean showcase of WHERE YOU ARE NOW.
/// The current-rank emblem is the centerpiece; below it sits a single "log a
/// set" action. No ladder, no requirements: you log a set to earn a rank, and
/// the rank-up reveals afterward — the climb and what-it-takes are deliberately
/// not shown here.
///
/// Exercises log inline via the ruler (the strength standard). Skills log one
/// set via the quick-log sheet — the single-source skill-ranking path — never a
/// session sheet and never bolted onto a strength ladder. A successful exercise
/// log pulses the emblem and shows a brief RANK UP banner; a skill log plays its
/// own reward sequence inside the sheet.
struct RankDetailRankTab: View {
    let vm: RankDetailViewModel
    var onLogged: (() async -> Void)?
    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Presentation-only state.
    @State private var errorMessage: String?
    @State private var isQuickLogPresented = false

    // Rank-up reveal (exercise/ruler case): emblem pulse + a brief banner.
    @State private var didRankUp = false
    @State private var rankUpBanner: String?
    @State private var bannerToken = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let banner = rankUpBanner {
                rankUpBannerView(banner)
                    // Reduce Motion: banner still appears/disappears but without the slide.
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            rankShowcase

            logSetSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isQuickLogPresented, onDismiss: {
            // The quick log may have ranked this skill up — reload the VM so the
            // showcase emblem refreshes, then bubble up so the library reloads.
            Task {
                await vm.load(services: services)
                await onLogged?()
            }
        }) {
            if let node = vm.skillNode {
                let cfg = skillQuickLogConfig(for: node)
                QuickLogSheet(
                    skillId: node.id,
                    skillTitle: node.title,
                    defaultReps: cfg.defaultReps,
                    isHoldBased: cfg.isHold,
                    holdTargetSeconds: cfg.holdSeconds
                )
            }
        }
        .alert("Couldn't save rank attempt", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Retry") { Task { await submit() } }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Your selections are still here.")
        }
    }

    // MARK: - Rank-up banner

    private func rankUpBannerView(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(vm.tint)
            Text(text)
                .font(Font.unbound.bodyLStrong)
                .tracking(0.4)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(vm.tint.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(vm.tint.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: vm.tint.opacity(0.3), radius: 12, y: 4)
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
                .scaleEffect(didRankUp ? 1.06 : 1.0)
                .shadow(
                    color: hidden ? .clear : vm.tint.opacity(didRankUp ? 0.9 : 0.5),
                    radius: didRankUp ? 28 : 18
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
            logSection(title: "LOG A SET") {
                VStack(alignment: .leading, spacing: 14) {
                    metricRail(definition)
                    rulerSubmitButton
                }
            }
        } else if vm.skillNode != nil {
            logSection(title: "LOG A SET") {
                skillLogButton
            }
        }
    }

    @ViewBuilder
    private func metricRail(_ definition: MovementDefinition) -> some View {
        switch vm.logMode {
        case .oneRepMax:
            oneRepMaxRail(definition)
        case .reps:
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
        case .hold:
            secondsRail
        }
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
        let step = 5
        let maxTick = 1_200 / step
        let tick = Binding<Int>(
            get: { min(max(Int((Double(vm.selectedSeconds) / Double(step)).rounded()), 1), maxTick) },
            set: { vm.selectedSeconds = max(1, min($0, maxTick)) * step }
        )
        return ProgramRankMetricRuler(
            title: "Hold Time",
            valueText: ProgramRankExerciseFormatter.seconds(vm.selectedSeconds),
            range: 1...maxTick,
            value: tick,
            format: { ProgramRankExerciseFormatter.seconds($0 * step) },
            tickLabel: { ProgramRankExerciseFormatter.seconds($0 * step) },
            majorEvery: 6,
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
                icon: vm.isSubmitting ? "hourglass" : "plus.circle.fill",
                title: vm.isSubmitting ? "Saving Set" : "Log a Set",
                borderTint: isEnabled ? vm.tint.opacity(0.72) : Color.unbound.border
            )
            .opacity(isEnabled ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("rankDetail.rank.logResult")
    }

    private var skillLogButton: some View {
        Button {
            UnboundHaptics.medium()
            isQuickLogPresented = true
        } label: {
            actionLabel(
                icon: "plus.circle.fill",
                title: "Log a Set",
                borderTint: vm.tint.opacity(0.72)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rankDetail.rank.logSet")
    }

    // MARK: - Submit + inline reveal (exercise/ruler case)

    private func submit() async {
        do {
            if let reveal = try await vm.submitLog(services: services) {
                await onLogged?()
                if reveal.isRankUp {
                    UnboundHaptics.success()
                    igniteRankUp(to: reveal.tier)
                } else {
                    UnboundHaptics.soft()
                }
            }
        } catch {
            HapticManager.notification(.error)
            errorMessage = error.localizedDescription
        }
    }

    /// Pulse the showcase emblem (now showing the new tier after `submitLog`'s
    /// reload) and show a banner that auto-dismisses after ~2s.
    /// Reduce Motion: state still updates (functional), but no spring/ease animation.
    private func igniteRankUp(to tier: SkillTier) {
        let token = UUID()
        bannerToken = token
        let apply = {
            didRankUp = true
            rankUpBanner = "RANK UP — \(tier.displayName)"
        }
        if reduceMotion {
            apply()
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { apply() }
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard bannerToken == token else { return }
            let clear = {
                didRankUp = false
                rankUpBanner = nil
            }
            if reduceMotion {
                clear()
            } else {
                withAnimation(.easeInOut(duration: 0.3)) { clear() }
            }
        }
    }

    /// Maps a skill node's target to the quick-log's metric + sensible defaults.
    /// Hold/carry skills log a timed hold; everything else logs reps.
    private func skillQuickLogConfig(for node: SkillNode) -> (isHold: Bool, defaultReps: Int, holdSeconds: Int) {
        switch node.target {
        case .hold(_, let seconds):
            return (true, 0, max(5, seconds))
        case .carry(_, let seconds, _):
            return (true, 0, max(5, seconds))
        case .reps(_, let count, _):
            return (false, max(1, count), 30)
        case .steps(_, let count):
            return (false, max(1, count), 30)
        case .weightMultiplier:
            return (false, 5, 30)
        case .composite(let reqs):
            for requirement in reqs {
                if case .hold(_, let seconds) = requirement { return (true, 0, max(5, seconds)) }
                if case .carry(_, let seconds, _) = requirement { return (true, 0, max(5, seconds)) }
            }
            for requirement in reqs {
                if case .reps(_, let count, _) = requirement { return (false, max(1, count), 30) }
                if case .steps(_, let count) = requirement { return (false, max(1, count), 30) }
            }
            return (false, 5, 30)
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
