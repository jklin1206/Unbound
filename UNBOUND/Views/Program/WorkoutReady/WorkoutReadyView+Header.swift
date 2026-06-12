import SwiftUI

extension WorkoutReadyView {
    @ViewBuilder
    var header: some View {
        if draft.isWeeklyVowDraft {
            weeklyProofHeader
        } else if isRankTrialDraft {
            rankTrialHeader
        } else {
            workoutHeader
        }
    }

    var workoutHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.source.rawValue.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.accent)
            Text(draft.title)
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
            MetaLine(["\(draft.blocks.count) blocks", "\(draft.estimatedMinutes) min"], emphasized: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var weeklyProofHeader: some View {
        let kind = weeklyVowKind
        let tint = weeklyProofTint
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                WeeklyVowProofAsset(kind: kind, tint: tint)
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 7) {
                    Text("BINDING VOW")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(tint)
                    Text(weeklyProofTitle)
                        .font(.system(.title2).weight(.black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    HStack(spacing: 8) {
                        readyChip(kind.displayName, icon: "checkmark.seal.fill")
                        readyChip("\(draft.estimatedMinutes) min", icon: "clock")
                    }
                }
                .layoutPriority(1)
            }

            WeeklyVowCoachValidationStrip(tint: tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    var weeklyProofWorkSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOU'LL DO")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)

            ForEach(Array(weeklyProofPrescriptions.prefix(4))) { prescription in
                HStack(spacing: 10) {
                    prescriptionVisual(for: prescription, tint: weeklyProofTint, size: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(prescription.exerciseName)
                            .font(Font.unbound.bodyS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                        Text("\(prescription.sets)x \(prescription.displayTargetText) · \(prescription.restSeconds)s rest\(rpeLabel(for: prescription))")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(cardBackground)
            }
        }
    }

    var rankTrialHeader: some View {
        let definition = rankTrialDefinition
        let tint = definition?.targetRank.rewardTextTint ?? Color.unbound.rankGold

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                    Image(systemName: rankTrialHeaderIconName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(tint)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 7) {
                    Text("OVERALL RANK TRIAL")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(tint)
                    Text(draft.title)
                        .font(.system(.title2).weight(.black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    HStack(spacing: 8) {
                        readyChip(definition?.format.displayName ?? "Rank Trial", icon: "flag.checkered")
                        readyChip("\(draft.blocks.count) stations", icon: "square.stack.3d.up")
                        readyChip("\(draft.estimatedMinutes) min", icon: "clock")
                    }
                }
                .layoutPriority(1)
            }

            Text(rankTrialHeaderSubtitle)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    var rankTrialProtocolSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW THIS TRIAL WORKS")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)

            Text(rankTrialHowItWorksText)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    var weeklyVowKind: WeeklyVowKind {
        WeeklyVowKind.kind(fromWeeklyVowRoute: draft.weeklyVowId)
            ?? WeeklyVowKind.kind(fromWeeklyVowRoute: draft.id)
            ?? .overdrive
    }

    var weeklyProofTint: Color {
        switch weeklyVowKind {
        case .ember:
            return Color.unbound.rankGreen
        case .overdrive:
            return Color.unbound.accent
        case .apex:
            return Color.unbound.rankGold
        }
    }

    var weeklyProofTitle: String {
        draft.title
            .replacingOccurrences(of: "Binding Vow - ", with: "")
            .replacingOccurrences(of: "Weekly Proof - ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var weeklyProofPrescriptions: [TrainingBlockPrescription] {
        draft.blocks.flatMap(\.prescriptions)
    }

    func rpeLabel(for prescription: TrainingBlockPrescription) -> String {
        guard let rpe = prescription.rpe else { return "" }
        return " · RPE \(rpe)"
    }

}
