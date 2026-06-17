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
        }
        .padding(.top, 4)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var homeMissionStatusBand: some View {
        HomeSurfaceBand(tint: homeControlTint, horizontalPadding: 0, verticalPadding: 14) {
            weekPath
        }
    }

    var homeTrialKeyBand: some View {
        HomeSurfaceBand(tint: homeControlTint, verticalPadding: 10) {
            VStack(alignment: .leading, spacing: 0) {
                HomeBandHeader(title: "Trials", tint: homeControlTint)
                    .padding(.bottom, 4)

                HomePriorityCommand(
                    artwork: .trialKey,
                    title: "Rank Trial",
                    detail: rankTrialCommandDetail,
                    value: rankTrialCommandValue,
                    tint: Color.unbound.rankGold,
                    accessibilityLabel: "Open rank trial"
                ) {
                    handleRankTrialCommand()
                }

                UnboundNativeDivider(opacity: 0.42)
                    .padding(.leading, 54)

                HomePriorityCommand(
                    artwork: .vow,
                    title: "Binding Vow",
                    detail: trialCommandDetail,
                    value: trialCommandValue,
                    tint: homeControlTint,
                    accessibilityLabel: "Open binding vow"
                ) {
                    handleTrialCommand()
                }
            }
        }
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

    var trialCommandValue: String {
        if let activeTrial = model.trialsState.currentTrial {
            return capstoneStateLabel(for: activeTrial.capstoneState)
        }
        if !model.trialsState.skippedCurrentWeek && !model.trialsState.currentWeekCards.isEmpty {
            return "BIND"
        }
        return "IDLE"
    }

    var trialCommandTint: Color {
        if let activeTrial = model.trialsState.currentTrial {
            if activeTrial.capstoneState == .completed { return Color.unbound.success }
            if activeTrial.capstoneState == .missed { return Color.unbound.alert }
            return activeTrial.chosenCard.lane.tintColor
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
        return rankGatePulseTint(readiness)
    }

    var rankTrialCommandDetail: String {
        guard let readiness = model.overallRankTrialReadiness,
              readiness.definition != nil
        else { return "Rank gate locked" }
        if readiness.isReady { return "Gate available" }
        if readiness.status == .attempted { return "Reattempt gate" }
        return "Rank gate progress"
    }

    var trialCommandDetail: String {
        let debt = model.trialsState.pendingVowDebtXP
        if let activeTrial = model.trialsState.currentTrial {
            switch activeTrial.capstoneState {
            case .pending:
                return debt > 0 ? "Log to seal · \(debt) XP debt" : "Log to seal · stake at risk"
            case .windowOpen:
                return "Final days to seal"
            case .completed:
                return debt > 0 ? "Sealed · \(debt) XP debt left" : "Reward sealed this week"
            case .missed:
                return debt > 0 ? "Missed · \(debt) XP debt" : "Missed this week"
            }
        }
        if debt > 0 {
            return "Vow debt · \(debt) XP"
        }
        if !model.trialsState.skippedCurrentWeek && !model.trialsState.currentWeekCards.isEmpty {
            return "Pick one vow or skip free"
        }
        return "No binding vow active"
    }

    var bodyWeightCommandValue: String {
        if let latestBodyWeightKg = model.latestBodyWeightKg {
            let weight = WeightPlatePolicy.formatLoggedWeight(latestBodyWeightKg, unit: selectedWeightUnit)
            return "\(weight) \(selectedWeightUnit.shortLabel)"
        }
        return model.hasLoggedBodyWeightToday ? "Logged" : "Log"
    }

    func handleTrialCommand() {
        if model.trialsState.currentTrial != nil {
            // Binding Vows v2: an active vow seals via auto-detection (recovery/
            // engine) or a Fuel self-report tap. Open the active-vow surface so
            // the in-context seal/self-report affordance (ActiveTrialCard) is
            // reachable from Home.
            UnboundHaptics.medium()
            showActiveVow = true
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
            return "ACTIVE"
        case .windowOpen:
            return "DUE"
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

private struct HomeSurfaceBand<Content: View>: View {
    let tint: Color
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 14
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surface.opacity(0.42),
                            tint.opacity(0.06),
                            Color.unbound.surface.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.74), lineWidth: 0.5)
        }
    }
}

private struct HomeBandHeader: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(tint)
                .frame(width: 3, height: 10)

            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)

            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.58))
                .frame(height: 0.5)
        }
    }
}

private struct HomePriorityCommand: View {
    let artwork: HomeCommandArtworkKind
    let title: String
    let detail: String
    let value: String
    let tint: Color
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                HomeCommandMiniGlyph(kind: artwork, tint: tint)
                    .frame(width: 42, height: 42)
                    .shadow(color: tint.opacity(0.18), radius: 6)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(detail.uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                Text(value.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(tint.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.26), lineWidth: 1))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
