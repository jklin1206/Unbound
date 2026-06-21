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
        HStack(alignment: .center, spacing: 7) {
            Rectangle()
                .fill(key.rewardTint)
                .frame(width: 3, height: 30)
                .opacity(isSelected ? 1 : 0.72)

            Text(key.displayName.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(key.rewardTint)
                .lineLimit(1)
                .minimumScaleFactor(0.42)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)

            AttributeRankBadge(rank: value.rankTitle, size: 20)
            Text("LVL \(value.level)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(0)
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .layoutPriority(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? key.rewardTint.opacity(0.10) : Color.unbound.surfaceElevated.opacity(0.18))
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(key.rewardTint.opacity(isSelected ? 0.70 : 0.28))
                .frame(height: 0.5)
        }
    }
}
