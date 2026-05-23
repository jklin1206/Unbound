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
        .accessibilityLabel("\(key.displayName), level \(value.level), \(value.rankTitle.displayName)")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(key.displayName)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(0)
                    .foregroundStyle(isSelected ? key.rewardTint : Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Spacer()
                Text("LVL \(value.level)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(0)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Image(value.rankTitle.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(value.rankTitle.displayName.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0)
                    .foregroundStyle(value.rankTitle.rewardTextTint)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? key.rewardTint.opacity(0.13) : Color.unbound.bg.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(key.rewardTint.opacity(isSelected ? 0.68 : 0.24), lineWidth: 1)
        )
    }
}
