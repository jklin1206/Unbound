import Foundation
import SwiftUI
import UIKit

extension UnboundHomeView {
    var homeControlTint: Color {
        Color.unbound.accent
    }

    var homeControlSurface: some View {
        VStack(spacing: 10) {
            homeMissionStatusBand
            homeUtilityDockBand
                .id("homeTiles")
            homeTrialKeyBand
        }
        .padding(.top, 4)
        .padding(.bottom, 20)
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
        VStack(alignment: .leading, spacing: 10) {
            HomeBandHeader(title: "Rank Trials & Vows")

            rankGateBlock

            vowStrip
        }
        .padding(.bottom, 2)
    }

    private var rankGateBlock: some View {
        HomeTrialDeck(
            gates: trialDeckGates,
            currentReadiness: model.overallRankTrialReadiness,
            onBegin: {
                if let definition = model.overallRankTrialReadiness?.definition {
                    enterRankGate(definition)
                }
            },
            onShowRecords: { showTrialRecords = true }
        )
    }

    /// All gate worlds with their cleared / current / locked state, in order — the
    /// swipeable deck source.
    private var trialDeckGates: [HomeTrialDeck.Gate] {
        let passedRanks = Set(rankGateProgress.attempts.filter { $0.passed }.map { $0.targetRank })
        let currentFormat = model.overallRankTrialReadiness?.definition?.format
        return RankTrialFormat.allCases.enumerated().map { index, format in
            let definition = OverallRankTrialDefinitions.all.first { $0.format == format }
            let state: HomeTrialDeck.GateState
            if let definition, passedRanks.contains(definition.targetRank) {
                state = .cleared
            } else if format == currentFormat {
                state = .current
            } else {
                state = .locked
            }
            return HomeTrialDeck.Gate(
                id: index,
                format: format,
                world: GateWorldCatalog.world(for: format),
                state: state
            )
        }
    }

    @ViewBuilder
    private var vowStrip: some View {
        if let trial = model.trialsState.currentTrial, trial.capstoneState != .missed {
            ActiveTrialCard(trial: trial)
        } else if model.trialsState.skippedCurrentWeek || model.trialsState.currentWeekCards.isEmpty {
            // Skipped (or no cards left) — a quiet status, not an inert CTA:
            // the pick strip's tap would no-op here, which reads as broken.
            vowRestWeekStrip
        } else {
            HomeVowPickStrip(onTap: { handleTrialCommand() })
        }
    }

    private var vowRestWeekStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text("BINDING VOW")
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("Resting this week · new vows next week")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
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
        .padding(.top, 5)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            UnboundNativeDivider(opacity: 0.54)
        }
        .overlay(alignment: .bottom) {
            UnboundNativeDivider(opacity: 0.36)
        }
    }

    var homeCommandStrip: some View {
        // One icon language for the whole dock: every glyph in the app accent,
        // every label in tertiary — two colors, no per-command tints or art.
        HStack(alignment: .top, spacing: 0) {
            HomeCommandStripButton(
                artwork: .weight,
                title: "Weight",
                tint: Color.unbound.accent,
                accessibilityLabel: "Open bodyweight log"
            ) {
                handleBodyWeightCommand()
            }

            HomeCommandStripButton(
                artwork: .backdrops,
                title: "Backdrops",
                tint: Color.unbound.accent,
                accessibilityLabel: "Change home backdrop"
            ) {
                UnboundHaptics.medium()
                showingBackdropPicker = true
            }

            HomeCommandStripButton(
                artwork: .rankLibrary,
                title: "Ranks",
                tint: Color.unbound.accent,
                accessibilityLabel: "Open rank library"
            ) {
                UnboundHaptics.soft()
                showRankLibrary = true
            }

            HomeCommandStripButton(
                artwork: .shop,
                title: "Shop",
                tint: Color.unbound.accent,
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
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Loading

}

private struct HomeBandHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color.unbound.accent)
                .frame(width: 5, height: 5)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)

            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.64))
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
            VStack(alignment: .center, spacing: 5) {
                HomeCommandMiniGlyph(kind: artwork, tint: tint)
                    .frame(width: 40, height: 40)

                Text(title.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.68)
                    .frame(height: 14, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
