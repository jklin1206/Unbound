import SwiftUI

extension WorkoutReadyView {
    @ViewBuilder
    var header: some View {
        if isRankTrialDraft {
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

}
