import SwiftUI
import UIKit

// MARK: - RoutinePreviewSheet

struct RoutinePreviewSheet: View {
    let routine: RoutineDef
    @Environment(\.dismiss) private var dismiss
    @State private var didComplete: Bool = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: routine.category.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                            Text(routine.category.label)
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(1.6)
                        }
                        .foregroundStyle(routine.category.color)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(routine.durationLabel)
                                .font(Font.unbound.monoS)
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text("·")
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text("PROOF-GATED XP")
                                .font(Font.unbound.monoM.weight(.bold))
                                .foregroundStyle(routine.category.color)
                        }
                    }

                    if let image = UIImage(named: routine.coverAssetName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 172)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, Color.unbound.bg.opacity(0.55)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(routine.category.color.opacity(0.22), lineWidth: 1)
                            )
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.title.uppercased())
                            .font(Font.unbound.titleL)
                            .tracking(0.4)
                            .foregroundStyle(Color.unbound.textPrimary)
                        RoutineDifficultyBadge(tier: routine.difficultyTier)
                            .padding(.top, 4)
                        Text(routine.subtitle)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !routine.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("HOW TO DO IT")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(2.0)
                                .foregroundStyle(Color.unbound.textTertiary)
                                .padding(.bottom, 10)

                            ForEach(Array(routine.steps.enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(i + 1)")
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(routine.category.color)
                                        .frame(width: 20, alignment: .trailing)
                                        .padding(.top, 1)
                                    Text(routineStepPreview(step))
                                        .font(Font.unbound.bodyM)
                                        .foregroundStyle(Color.unbound.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 10)
                                if i < routine.steps.count - 1 {
                                    Divider()
                                        .background(Color.unbound.borderSubtle)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.unbound.border, lineWidth: 1)
                        )
                    }

                    let canComplete = RoutineHistoryStore.shared.canComplete(routineId: routine.id)
                    let label: String = {
                        if didComplete { return "PROOF LOGGED" }
                        if !canComplete { return "DONE TODAY · COME BACK TOMORROW" }
                        return "CLOSE PREVIEW"
                    }()
                    let icon: String = {
                        if didComplete || !canComplete { return "checkmark.seal.fill" }
                        return "xmark"
                    }()
                    let isDisabled = didComplete || !canComplete

                    Button {
                        UnboundHaptics.medium()
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Text(label)
                                .font(Font.unbound.bodyMStrong)
                                .tracking(1.6)
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(routine.category.color)
                        )
                        .opacity(isDisabled ? 0.55 : 1.0)
                        .shadow(color: routine.category.color.opacity(0.45), radius: 10, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)

                    Spacer().frame(height: 8)
                }
                .padding(24)
            }
        }
    }
}
