import SwiftUI
import UIKit

// MARK: - Routine challenge carousel

struct RoutineChallengeCard: View {
    let routine: RoutineDef

    private var canComplete: Bool {
        RoutineHistoryStore.shared.canComplete(routineId: routine.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                routineCover
                    .frame(height: 198)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                LinearGradient(
                    colors: [.clear, Color.unbound.bg.opacity(0.70), Color.unbound.bg.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    statusChip
                    Text(routine.title.uppercased())
                        .font(Font.unbound.titleL)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                    Text(routine.subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                }
                .padding(18)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    metricPill(value: routine.durationLabel, label: "TIME")
                    rankMetricPill(tier: routine.difficultyTier)
                    metricPill(value: "PROOF", label: "LVL XP")
                }

                HStack(spacing: 12) {
                    Text(routine.steps.first.map(routineStepPreview) ?? "Open the mission and start.")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Text(canComplete ? "READY" : "OPEN")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.4)
                        Image(systemName: canComplete ? "arrow.right" : "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color.unbound.bg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(canComplete ? routine.category.color : Color.unbound.textTertiary))
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(routine.category.color.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: routine.category.color.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var routineCover: some View {
        if let image = UIImage(named: routine.coverAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .saturation(canComplete ? 1 : 0.25)
                .opacity(canComplete ? 0.9 : 0.48)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        routine.category.color.opacity(0.46),
                        Color.unbound.emberDeep.opacity(0.34),
                        Color.unbound.bg
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Path { path in
                    path.move(to: CGPoint(x: 24, y: 146))
                    path.addCurve(
                        to: CGPoint(x: 190, y: 44),
                        control1: CGPoint(x: 78, y: 92),
                        control2: CGPoint(x: 114, y: 34)
                    )
                    path.addCurve(
                        to: CGPoint(x: 335, y: 118),
                        control1: CGPoint(x: 252, y: 54),
                        control2: CGPoint(x: 262, y: 146)
                    )
                }
                .stroke(
                    routine.category.color.opacity(0.72),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: routine.category.color.opacity(0.30), radius: 10)

                Image(systemName: routine.category.systemImage)
                    .font(.system(size: 118, weight: .black))
                    .foregroundStyle(routine.category.color.opacity(0.18))
                    .offset(x: 90, y: -34)
            }
        }
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(canComplete ? routine.category.color : Color.unbound.textTertiary)
                .frame(width: 6, height: 6)
            Text(canComplete ? "MISSION READY" : "CLEARED TODAY")
                .font(Font.unbound.monoS.weight(.heavy))
                .tracking(1.3)
        }
        .foregroundStyle(canComplete ? routine.category.color : Color.unbound.textTertiary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.unbound.bg.opacity(0.62)))
        .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }

    private func metricPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
    }

    private func rankMetricPill(tier: SkillTier) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(tier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)

                Text(tier.displayName.uppercased())
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            Text("RANK")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tier.rewardTextTint.opacity(0.24), lineWidth: 1)
        )
        .accessibilityLabel("\(tier.displayName) routine rank")
    }
}
