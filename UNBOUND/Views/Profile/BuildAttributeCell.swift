// UNBOUND/Views/Profile/BuildAttributeCell.swift
import SwiftUI

struct BuildAttributeCell: View {
    let key: AttributeKey
    let value: AttributeValue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(key.shortCode)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("\(Int(value.current.rounded()))")
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            Rectangle()
                .fill(Color.unbound.surface)
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.unbound.accent)
                            .frame(width: geo.size.width * CGFloat(value.current / 100))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))

            HStack(spacing: 5) {
                Circle()
                    .fill(isHighTier ? Color.unbound.accent : Color.unbound.textTertiary)
                    .frame(width: 5, height: 5)
                Text(value.rankTitle.displayName.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(isHighTier ? Color.unbound.accent : Color.unbound.textSecondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.border.opacity(0.6), lineWidth: 1)
        )
    }

    private var isHighTier: Bool {
        switch value.rankTitle {
        case .honed, .vessel, .unbound, .ascendant: return true
        default: return false
        }
    }
}
