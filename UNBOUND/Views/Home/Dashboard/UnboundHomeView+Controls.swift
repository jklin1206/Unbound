import Foundation
import SwiftUI
import UIKit

extension UnboundHomeView {
    var homeControlTint: Color {
        Color.unbound.accent
    }

    var homeControlSurface: some View {
        VStack(spacing: 12) {
            homeMissionStatusBand
            homeTrialKeyBand
            homeUtilityDockBand
                .id("homeTiles")
        }
        .padding(.top, 4)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var homeMissionStatusBand: some View {
        weekPath
    }

    // The rank gate is its own immersive "world" card (NextGateCard) placed
    // directly on Home — ENTER drops you into the trial, so we don't re-open a
    // detail sheet (that would just show the same card twice). The Trial Records
    // row beneath it opens the full 8-gate list. The vow is a separate, slim
    // strip — a weekly self-report habit, not a place you enter.
    var homeTrialKeyBand: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeBandHeader(title: "Trials")

            rankGateBlock

            vowStrip
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var rankGateBlock: some View {
        if let readiness = model.overallRankTrialReadiness,
           let definition = readiness.definition {
            VStack(spacing: 10) {
                NextGateCard(
                    readiness: readiness,
                    world: GateWorldCatalog.world(for: definition.format),
                    onBegin: { enterRankGate(definition) }
                )
                HomeGateProgressionStrip(states: gateMarkerStates(), onTap: { showTrialRecords = true })
            }
        } else if passedGateCount >= RankTrialFormat.allCases.count {
            VStack(spacing: 10) {
                HomeAllGatesClearedCard(peakRankName: model.aggregateTier.displayName)
                HomeGateProgressionStrip(states: gateMarkerStates(), onTap: { showTrialRecords = true })
            }
        } else {
            HomeRankGateLockedRow(
                detail: "No gate available",
                onTap: { showTrialRecords = true }
            )
        }
    }

    @ViewBuilder
    private var vowStrip: some View {
        if let trial = model.trialsState.currentTrial, trial.capstoneState != .missed {
            ActiveTrialCard(trial: trial)
        } else {
            HomeVowPickStrip(onTap: { handleTrialCommand() })
        }
    }

    // MARK: - Rank gate helpers

    /// Persisted gate attempts/records for the current user.
    var rankGateProgress: OverallRankTrialProgress {
        OverallRankTrialStore.shared.load(userId: services.auth.currentUserId ?? "anonymous")
    }

    /// Distinct ranks whose gate has at least one passing attempt.
    var passedGateCount: Int {
        Set(rankGateProgress.attempts.filter { $0.passed }.map { $0.targetRank }).count
    }

    /// Per-gate state for the progression strip — cleared (passed), current (the
    /// gate you're working on now), or locked.
    func gateMarkerStates() -> [HomeGateMarkerState] {
        let passedRanks = Set(rankGateProgress.attempts.filter { $0.passed }.map { $0.targetRank })
        let currentFormat = model.overallRankTrialReadiness?.definition?.format
        return RankTrialFormat.allCases.map { format in
            let def = OverallRankTrialDefinitions.all.first { $0.format == format }
            if let def, passedRanks.contains(def.targetRank) { return .cleared }
            if format == currentFormat { return .current }
            return .locked
        }
    }

    /// ENTER on the world card → straight into the trial workout cover (no detail
    /// sheet). Mirrors the path the records list uses to re-enter a gate.
    func enterRankGate(_ definition: OverallRankTrialDefinition) {
        let userId = services.auth.currentUserId ?? "anonymous"
        let readiness = model.overallRankTrialReadiness
        let resolvedTrial = readiness?.resolvedTrial?.definitionId == definition.id
            ? readiness?.resolvedTrial
            : nil
        UnboundHaptics.medium()
        workoutReadyDraft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: userId,
            resolvedTrial: resolvedTrial,
            bodyweightKg: model.profile?.weightKg
        )
    }

    var homeUtilityDockBand: some View {
        homeCommandStrip
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            UnboundNativeDivider(opacity: 0.54)
        }
        .overlay(alignment: .bottom) {
            UnboundNativeDivider(opacity: 0.36)
        }
    }

    var homeCommandStrip: some View {
        HStack(alignment: .top, spacing: 0) {
            HomeCommandStripButton(
                artwork: .weight,
                title: "Weight",
                tint: bodyWeightStatusColor,
                accessibilityLabel: "Open bodyweight log"
            ) {
                handleBodyWeightCommand()
            }

            HomeCommandStripButton(
                artwork: .backdrops,
                title: "Backdrops",
                tint: equippedHomeBackdrop?.accent ?? Color.skinHex("2DD4BF"),
                accessibilityLabel: "Change home backdrop"
            ) {
                UnboundHaptics.medium()
                showingBackdropPicker = true
            }

            HomeCommandStripButton(
                artwork: .rankLibrary,
                title: "Ranks",
                tint: model.aggregateTier.rewardTextTint,
                accessibilityLabel: "Open rank library"
            ) {
                UnboundHaptics.soft()
                showRankLibrary = true
            }

            HomeCommandStripButton(
                artwork: .shop,
                title: "Shop",
                tint: Color.skinHex("8B5CF6"),
                accessibilityLabel: "Open cosmetics shop"
            ) {
                UnboundHaptics.medium()
                showingShop = true
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }

    var bodyWeightCommandValue: String {
        if let latestBodyWeightKg = model.latestBodyWeightKg {
            let weight = WeightPlatePolicy.formatLoggedWeight(latestBodyWeightKg, unit: selectedWeightUnit)
            return "\(weight) \(selectedWeightUnit.shortLabel)"
        }
        return model.hasLoggedBodyWeightToday ? "Logged" : "Log"
    }

    func handleTrialCommand() {
        // An active vow is logged inline on the Home feed (ActiveTrialCard in the
        // contextual stack), so the tile is just its status here. Only the pick
        // entry (no active vow yet) opens anything.
        guard model.trialsState.currentTrial == nil else {
            UnboundHaptics.soft()
            return
        }
        guard !model.trialsState.skippedCurrentWeek,
              !model.trialsState.currentWeekCards.isEmpty
        else {
            UnboundHaptics.soft()
            return
        }

        UnboundHaptics.medium()
        showTrialPicker = true
    }

    func handleBodyWeightCommand() {
        model.bodyWeightSaveError = nil
        UnboundHaptics.medium()
        if model.hasLoggedBodyWeightToday {
            showingBodyWeightHistory = true
        } else {
            showingBodyWeightLog = true
        }
    }

    var bodyWeightQuickLogRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                UnboundHaptics.medium()
                showingBodyWeightHistory = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.hasLoggedBodyWeightToday ? "checkmark.circle.fill" : "scalemass.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(bodyWeightStatusColor)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(bodyWeightValueText)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text(selectedWeightUnit.shortLabel.uppercased())
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(Color.unbound.textSecondary)
                        }

                        Text(bodyWeightRecencyText)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(bodyWeightStatusColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open bodyweight history")

            Button {
                model.bodyWeightSaveError = nil
                UnboundHaptics.medium()
                showingBodyWeightLog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: model.hasLoggedBodyWeightToday ? "checkmark" : "plus")
                        .font(.system(size: 10, weight: .black))
                    Text(model.hasLoggedBodyWeightToday ? "LOGGED" : "LOG")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule()
                        .fill(bodyWeightStatusColor.opacity(model.hasLoggedBodyWeightToday ? 0.20 : 0.92))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(bodyWeightStatusColor.opacity(0.40), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log bodyweight")
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.62))
                .frame(height: 0.5)
        }
    }

    // MARK: - Contextual stack

    @ViewBuilder
    var contextualStack: some View {
        VStack(spacing: 12) {
            RecalibratingBanner()

            if model.shouldShowCalibrationCard {
                DayOneCalibrationCard(style: .slim) {
                    UnboundHaptics.medium()
                    showingCalibrationWorkout = true
                }
            }

        }
    }

    var shouldShowRankGatePulse: Bool {
        guard let readiness = model.overallRankTrialReadiness,
              readiness.definition != nil
        else { return false }
        return true
    }

    func rankGatePulseCard(_ readiness: OverallRankTrialReadiness) -> some View {
        let tint = rankGatePulseTint(readiness)
        let target = readiness.targetRank?.displayName ?? "Title"
        let metCount = readiness.requirements.filter(\.isMet).count
        let totalCount = max(1, readiness.requirements.count)

        return Button {
            UnboundHaptics.soft()
            NotificationCenter.default.post(name: .requestOpenRankInfo, object: nil)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tint)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text("RANK TRIAL")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(rankGatePulseStatus(readiness))
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(tint)
                    }

                    Text("\(target) Trial · \(metCount)/\(totalCount) proofs")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(rankGatePulseDetail(readiness))
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                UnboundNativeDivider(opacity: 0.42)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.rankGatePulse")
    }

    func rankGatePulseStatus(_ readiness: OverallRankTrialReadiness) -> String {
        if readiness.isReady { return "READY" }
        if readiness.status == .attempted { return "REBUILD" }
        let missing = readiness.missingRequirements.count
        if missing == 1 { return "1 LEFT" }
        return "\(missing) LEFT"
    }

    func rankGatePulseDetail(_ readiness: OverallRankTrialReadiness) -> String {
        if readiness.isReady {
            return "All proofs are in. Open Profile to run the trial."
        }
        if readiness.status == .attempted {
            return "Trial attempted. Rebuild the missing proofs before the next run."
        }
        if let closest = readiness.missingRequirements.first {
            return "Next proof: \(closest.label) · \(closest.current) of \(closest.required)"
        }
        return "Open Profile for the full trial checklist."
    }

    func rankGatePulseTint(_ readiness: OverallRankTrialReadiness) -> Color {
        if readiness.isReady {
            return readiness.targetRank?.rewardTextTint ?? Color.unbound.accent
        }
        return Color.unbound.rankGold
    }

    // MARK: - Stats grid


    // MARK: - Last session recap (inline, no card)

    @ViewBuilder
    var lastSessionRecap: some View {
        if let log = model.lastLog {
            HStack(spacing: 6) {
                Text(dayWord(for: log.startedAt))
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("·")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(log.plannedWorkoutName.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Loading

}

private struct HomeBandHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)

            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.58))
                .frame(height: 0.5)
        }
    }
}

private struct HomeCommandStripButton: View {
    let artwork: HomeCommandArtworkKind
    let title: String
    let tint: Color
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 7) {
                HomeCommandMiniGlyph(kind: artwork, tint: tint)
                    .frame(width: 38, height: 38)

                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.68)
                    .frame(height: 20, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
