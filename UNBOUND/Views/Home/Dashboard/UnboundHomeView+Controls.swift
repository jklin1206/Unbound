import Foundation
import SwiftUI
import UIKit

extension UnboundHomeView {
    var homeControlSurface: some View {
        VStack(spacing: 12) {
            weekPath
            homeCommandCenter
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

    var homeCommandCenter: some View {
        VStack(spacing: 14) {
            HomeCommandSection(
                title: "Progression",
                palette: .progression,
                commands: [
                    HomeCommand(
                        artwork: .rankTrial,
                        title: "Gate Keys",
                        detail: rankTrialCommandValue,
                        accessibilityLabel: "Open rank trial"
                    ) { handleRankTrialCommand() },
                    HomeCommand(
                        artwork: .vow,
                        title: "Vows",
                        detail: trialCommandValue,
                        accessibilityLabel: "Open weekly vow"
                    ) { handleTrialCommand() },
                    HomeCommand(
                        artwork: .rankLibrary,
                        title: "Rank Library",
                        detail: model.aggregateTier.displayName,
                        accessibilityLabel: "Open rank library"
                    ) { showRankLibrary = true }
                ]
            )

            HomeCommandSection(
                title: "Cosmetics",
                palette: .cosmetics,
                commands: [
                    HomeCommand(
                        artwork: .shop,
                        title: "Shop",
                        detail: "\(shopInventoryStore.purchasedItemIDs.count) owned",
                        accessibilityLabel: "Open cosmetics shop"
                    ) { showingShop = true },
                    HomeCommand(
                        artwork: .backdrops,
                        title: "Backdrops",
                        detail: equippedHomeBackdrop?.name ?? "Default",
                        accessibilityLabel: "Change home backdrop"
                    ) { showingBackdropPicker = true },
                    HomeCommand(
                        artwork: .weight,
                        title: "Weight",
                        detail: bodyWeightCommandValue,
                        accessibilityLabel: "Open bodyweight log"
                    ) { handleBodyWeightCommand() }
                ]
            )
        }
        .frame(maxWidth: .infinity)
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
        NotificationCenter.default.post(name: .requestOpenRankInfo, object: nil)
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
