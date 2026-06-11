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
        HStack(alignment: .center, spacing: 8) {
            Rectangle()
                .fill(key.rewardTint)
                .frame(width: 3, height: 30)
                .opacity(isSelected ? 1 : 0.72)

            VStack(alignment: .leading, spacing: 3) {
                Text(key.displayName.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(key.rewardTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                HStack(spacing: 5) {
                    AttributeRankBadge(rank: value.rankTitle, size: 16)
                    Text("LVL \(value.level)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(key.rewardTint.opacity(isSelected ? 0.70 : 0.28))
                .frame(height: 0.5)
        }
    }
}
