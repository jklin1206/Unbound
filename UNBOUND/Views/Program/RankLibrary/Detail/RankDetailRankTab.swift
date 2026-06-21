import SwiftUI

/// Rank tab of the unified rank detail — the centerpiece. Top to bottom:
/// a compact current-tier + next-gate header, the all-ranks CLIMB visual (a
/// vertical ladder with a connecting progress spine), and the "Log a Set"
/// action (ruler for exercises, session sheet for pure skills).
///
/// A successful log animates inline: the newly-reached rung ignites, the spine
/// fills up to it, and a brief "RANK UP" banner appears at the top — no
/// full-screen overlay. The ladder data itself refreshes via `vm.submitLog`,
/// which re-loads the view model; this tab owns the emphasis + banner state.
struct RankDetailRankTab: View {
    let vm: RankDetailViewModel
    var onLogged: (() async -> Void)?
    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Presentation-only state for the inline reveal + logging flow.
    @State private var errorMessage: String?
    @State private var isSessionPresented = false

    /// The tier of the rung to ignite after a rank-up, cleared once the banner
    /// auto-dismisses. Drives the scale/glow emphasis on that single rung.
    @State private var ignitedTier: SkillTier?
    /// "RANK UP — <Tier>" banner copy; non-nil while the banner shows.
    @State private var rankUpBanner: String?
    /// Identity for the auto-dismiss task so a rapid second rank-up restarts it.
    @State private var bannerToken = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let banner = rankUpBanner {
                rankUpBannerView(banner)
                    // Reduce Motion: banner still appears/disappears but without the slide.
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            header

            ladderClimb

            logSetSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $isSessionPresented, onDismiss: {
            // The session may have ranked this skill up — reload the VM so the
            // climb + current-rank header refresh from the skill's new tier, then
            // bubble up so the library list refreshes too.
            Task {
                await vm.load(services: services)
                await onLogged?()
            }
        }) {
            if let node = vm.skillNode {
                SkillSessionView(skillId: node.id, skillTitle: node.title)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
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

    // MARK: - 1. Compact header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                Image(vm.displayedTier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .shadow(color: vm.tint.opacity(0.4), radius: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text("CURRENT RANK")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(vm.displayedTier.displayName.uppercased())
                        .font(Font.unbound.titleS.weight(.black))
                        .foregroundStyle(vm.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }

            if let gateText = vm.nextGateText {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(vm.tint)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXT GATE")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(gateText)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.surface)
                )
            }
        }
    }

    // MARK: - 2. The all-ranks CLIMB

    @ViewBuilder
    private var ladderClimb: some View {
        if vm.ladderRows.isEmpty {
            ladderEmptyState
        } else {
            VStack(alignment: .leading, spacing: 9) {
                Text("THE CLIMB")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textTertiary)

                // Highest tier first (Unbound → Initiate), so the climb reads
                // top-down with the peak at the top.
                let rungs = Array(vm.ladderRows.reversed())
                VStack(spacing: 0) {
                    ForEach(Array(rungs.enumerated()), id: \.element.id) { index, rung in
                        RankClimbRung(
                            rung: rung,
                            tint: vm.tint,
                            isFirst: index == 0,
                            isLast: index == rungs.count - 1,
                            isIgnited: ignitedTier == rung.tier
                        )
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.unbound.bg.opacity(0.34))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
            }
        }
    }

    private var ladderEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No rank data")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Standards aren't available for this movement yet.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }

    // MARK: - 3. Log a Set

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
            logSection(title: "TRAIN THIS SKILL") {
                skillSessionButton
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
                icon: vm.isSubmitting ? "hourglass" : "sparkles",
                title: vm.isSubmitting ? "Saving Attempt" : "Reveal Rank",
                borderTint: isEnabled ? vm.tint.opacity(0.72) : Color.unbound.border
            )
            .opacity(isEnabled ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("rankDetail.rank.logResult")
    }

    private var skillSessionButton: some View {
        Button {
            UnboundHaptics.medium()
            isSessionPresented = true
        } label: {
            actionLabel(
                icon: "dumbbell.fill",
                title: "Start Session",
                borderTint: vm.tint.opacity(0.72)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rankDetail.rank.startSession")
    }

    // MARK: - Submit + inline reveal

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

    /// Drive the inline rank-up reveal: ignite the reached rung, fill the
    /// spine up to it (the rung's own `isCleared` is now true after reload), and
    /// show a banner that auto-dismisses after ~2s.
    /// Reduce Motion: state still updates (functional), but no spring/ease animation.
    private func igniteRankUp(to tier: SkillTier) {
        let token = UUID()
        bannerToken = token
        if reduceMotion {
            ignitedTier = tier
            rankUpBanner = "RANK UP — \(tier.displayName)"
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                ignitedTier = tier
                rankUpBanner = "RANK UP — \(tier.displayName)"
            }
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard bannerToken == token else { return }
            if reduceMotion {
                rankUpBanner = nil
                ignitedTier = nil
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    rankUpBanner = nil
                    ignitedTier = nil
                }
            }
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

// MARK: - Climb rung

/// One rung of the vertical climb. A connecting spine runs down the left edge:
/// the segment is filled in `tint` once the rung above it is cleared and the
/// rung itself is reached, hollow otherwise. The current/next rung is
/// emphasized with a larger shield, a tint glow, and a "NEXT" marker; cleared
/// rungs get a subtle check; locked rungs are dimmed.
private struct RankClimbRung: View {
    let rung: RankLadderRow
    let tint: Color
    let isFirst: Bool
    let isLast: Bool
    let isIgnited: Bool

    private var isEmphasized: Bool { rung.isCurrent || rung.isNext }
    private var isLocked: Bool { !rung.isCleared && !isEmphasized }

    private var rowTint: Color {
        if rung.isCleared { return Color.unbound.success }
        if isEmphasized { return tint }
        return Color.unbound.textTertiary
    }

    private var shieldSize: CGFloat { isEmphasized ? 38 : 28 }

    /// The upper spine segment (toward higher tiers, drawn above this rung) is
    /// filled when this rung is cleared — i.e. you've climbed past it.
    private var upperFilled: Bool { rung.isCleared }
    /// The lower spine segment (toward lower tiers) is filled when this rung is
    /// reached at all (cleared or the current target the spine climbs into).
    private var lowerFilled: Bool { rung.isCleared || isEmphasized }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            spine
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(rung.tier.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(0.9)
                        .foregroundStyle(rowTint)
                    if isEmphasized { nextMarker }
                    Spacer(minLength: 0)
                    if rung.isCleared {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color.unbound.success)
                    }
                }
                Text(rung.criteriaText)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(isLocked ? Color.unbound.textTertiary : Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, isEmphasized ? 7 : 2)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 8)
        .background(
            Group {
                if isEmphasized {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.08))
                        .padding(.vertical, 2)
                }
            }
        )
    }

    /// Vertical spine: a connecting line behind a tier shield. Cleared segments
    /// glow `tint`; future segments are hollow (`borderSubtle`).
    private var spine: some View {
        VStack(spacing: 0) {
            // Upper connector (hidden for the very first/top rung).
            Rectangle()
                .fill(upperFilled ? tint : Color.unbound.borderSubtle)
                .frame(width: 2.5)
                .frame(height: 12)
                .opacity(isFirst ? 0 : 1)

            shield
                .scaleEffect(isIgnited ? 1.18 : 1.0)

            // Lower connector (hidden for the very last/bottom rung).
            Rectangle()
                .fill(lowerFilled ? tint : Color.unbound.borderSubtle)
                .frame(width: 2.5)
                .frame(maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
    }

    private var shield: some View {
        Image(rung.tier.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: shieldSize, height: shieldSize)
            .opacity(isLocked ? 0.35 : 1.0)
            .shadow(
                color: (isEmphasized || isIgnited) ? tint.opacity(isIgnited ? 0.85 : 0.45) : .clear,
                radius: isIgnited ? 16 : (isEmphasized ? 8 : 0)
            )
    }

    private var nextMarker: some View {
        Text("NEXT")
            .font(.system(size: 8, weight: .heavy, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint.opacity(0.16))
            )
    }
}
