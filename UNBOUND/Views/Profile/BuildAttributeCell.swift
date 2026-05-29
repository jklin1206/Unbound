// UNBOUND/Views/Profile/BuildAttributeCell.swift
import SwiftUI

struct BuildAttributeCell: View {
    let key: AttributeKey
    let value: AttributeValue
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            content
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(key.displayName), \(value.rankTitle.displayName) rank, level \(value.level)")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(key.displayName)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(0)
                    .foregroundStyle(key.rewardTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Spacer()
                HStack(spacing: 5) {
                    AttributeRankBadge(rank: value.rankTitle, size: 18)
                    Text("LVL \(value.level)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            key.rewardTint.opacity(isSelected ? 0.22 : 0.13),
                            Color.unbound.bg.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(key.rewardTint.opacity(isSelected ? 0.82 : 0.42), lineWidth: 1)
        )
        .shadow(color: key.rewardTint.opacity(isSelected ? 0.2 : 0.08), radius: isSelected ? 10 : 5, y: 3)
    }
}
