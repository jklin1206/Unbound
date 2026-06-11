import Foundation
import SwiftUI
import UIKit

extension UnboundHomeView {
    var homeControlSurface: some View {
        VStack(spacing: 12) {
            weekPath
            homeIconDock
            activeVowInlineStatus
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.64))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.42))
                .frame(height: 0.5)
        }
    }

    var homeIconDock: some View {
        let columns = [
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10)
        ]

        return LazyVGrid(columns: columns, spacing: 8) {
            HomeIconCommand(
                artwork: .rankTrial,
                title: "Rank Trial",
                value: rankTrialCommandValue,
                tint: rankTrialCommandTint,
                accessibilityLabel: "Open rank trial"
            ) {
                handleRankTrialCommand()
            }

            HomeIconCommand(
                artwork: .vow,
                title: "Vows",
                value: trialCommandValue,
                tint: trialCommandTint,
                accessibilityLabel: "Open weekly vow"
            ) {
                handleTrialCommand()
            }

            HomeIconCommand(
                artwork: .shop,
                title: "Shop",
                value: "\(shopInventoryStore.purchasedItemIDs.count) owned",
                tint: Color.skinHex("8B5CF6"),
                accessibilityLabel: "Open cosmetics shop"
            ) {
                UnboundHaptics.medium()
                showingShop = true
            }

            HomeIconCommand(
                artwork: .backdrops,
                title: "Backdrops",
                value: equippedHomeBackdrop?.name ?? "Default",
                tint: equippedHomeBackdrop?.accent ?? Color.skinHex("2DD4BF"),
                accessibilityLabel: "Change home backdrop"
            ) {
                UnboundHaptics.medium()
                showingBackdropPicker = true
            }

            HomeIconCommand(
                artwork: .rankLibrary,
                title: "Rank Library",
                value: model.aggregateTier.displayName,
                tint: model.aggregateTier.rewardTextTint,
                accessibilityLabel: "Open rank library"
            ) {
                UnboundHaptics.soft()
                showRankLibrary = true
            }

            HomeIconCommand(
                artwork: .weight,
                title: "Weight",
                value: bodyWeightCommandValue,
                tint: bodyWeightStatusColor,
                accessibilityLabel: "Open bodyweight log"
            ) {
                handleBodyWeightCommand()
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    var activeVowInlineStatus: some View {
        if let activeTrial = model.trialsState.currentTrial,
           activeTrial.capstoneState != .missed {
            Button {
                handleTrialCommand()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: activeTrial.capstoneState == .windowOpen ? "play.fill" : "seal.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(activeTrial.chosenCard.theme.tintColor)
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text("BINDING VOW")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text(capstoneStateLabel(for: activeTrial.capstoneState))
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(activeTrial.chosenCard.theme.tintColor)
                        }

                        Text(activeTrial.chosenCard.displayName)
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }

                    Spacer(minLength: 0)

                    if activeTrial.capstoneState == .windowOpen {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(activeTrial.chosenCard.theme.tintColor)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Weekly vow \(activeTrial.chosenCard.displayName)")
        }
    }

    var trialCommandValue: String {
        if let activeTrial = model.trialsState.currentTrial {
            return capstoneStateLabel(for: activeTrial.capstoneState)
        }
        if !model.trialsState.skippedCurrentWeek && !model.trialsState.currentWeekCards.isEmpty {
            return "PICK"
        }
        return "IDLE"
    }

    var trialCommandTint: Color {
        if let activeTrial = model.trialsState.currentTrial {
            if activeTrial.capstoneState == .completed { return Color.unbound.success }
            if activeTrial.capstoneState == .missed { return Color.unbound.alert }
            return activeTrial.chosenCard.theme.tintColor
        }
        if !model.trialsState.skippedCurrentWeek && !model.trialsState.currentWeekCards.isEmpty {
            return Color.unbound.accent
        }
        return Color.unbound.textTertiary
    }

    var rankTrialCommandValue: String {
        guard let readiness = model.overallRankTrialReadiness,
              readiness.definition != nil
        else { return "IDLE" }
        if readiness.isReady { return "READY" }
        if readiness.status == .attempted { return "RETRY" }
        let metCount = readiness.requirements.filter(\.isMet).count
        let totalCount = max(1, readiness.requirements.count)
        return "\(metCount)/\(totalCount)"
    }

    var rankTrialCommandTint: Color {
        guard let readiness = model.overallRankTrialReadiness,
              readiness.definition != nil
        else { return Color.unbound.textTertiary }
        if readiness.isReady {
            return readiness.targetRank?.rewardTextTint ?? Color.unbound.accent
        }
        return Color.unbound.rankGold
    }

    var bodyWeightCommandValue: String {
        if let latestBodyWeightKg = model.latestBodyWeightKg {
            let weight = WeightPlatePolicy.formatLoggedWeight(latestBodyWeightKg, unit: selectedWeightUnit)
            return "\(weight) \(selectedWeightUnit.shortLabel)"
        }
        return model.hasLoggedBodyWeightToday ? "Logged" : "Log"
    }

    func handleTrialCommand() {
        if let activeTrial = model.trialsState.currentTrial {
            guard activeTrial.capstoneState == .windowOpen else {
                UnboundHaptics.soft()
                return
            }
            UnboundHaptics.medium()
            workoutReadyDraft = services.trials.trainingDraft(for: activeTrial, date: Date())
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

    func handleRankTrialCommand() {
        guard let readiness = model.overallRankTrialReadiness,
              readiness.definition != nil
        else {
            UnboundHaptics.soft()
            return
        }
        UnboundHaptics.medium()
        NotificationCenter.default.post(name: .requestNavigateToProfileRankGate, object: nil)
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

    func capstoneStateLabel(for state: WeeklyVowState) -> String {
        switch state {
        case .pending:
            return "ARMED"
        case .windowOpen:
            return "OPEN"
        case .completed:
            return "DONE"
        case .missed:
            return "MISSED"
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
