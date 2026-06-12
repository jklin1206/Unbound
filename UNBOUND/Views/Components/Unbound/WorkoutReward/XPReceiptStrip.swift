import SwiftUI
import UIKit

struct XPReceiptStrip: View {
    let xp: XPReward
    let animatedXP: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            receiptCell(label: "GAINED", value: "+\(compactNumber(Double(max(0, animatedXP)))) XP", tint: tint)
            receiptDivider
            receiptCell(label: "TOTAL", value: "\(compactNumber(xp.currentXP)) XP", tint: Color.unbound.textPrimary)
            receiptDivider
            receiptCell(label: "TO NEXT", value: "\(compactNumber(xp.xpRemainingInLevel)) XP", tint: Color.unbound.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.26), lineWidth: 1)
        )
    }

    private var receiptDivider: some View {
        Rectangle()
            .fill(Color.unbound.borderSubtle)
            .frame(width: 1, height: 32)
    }

    private func receiptCell(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.54)
                .allowsTightening(true)
                .multilineTextAlignment(.center)

            Text(label)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
    }

    private func compactNumber(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        let magnitude = abs(value)

        if magnitude >= 1_000_000 {
            return sign + trimmedDecimal(magnitude / 1_000_000) + "M"
        }

        if magnitude >= 10_000 {
            return sign + "\(Int((magnitude / 1_000).rounded()))K"
        }

        if magnitude >= 1_000 {
            return sign + trimmedDecimal(magnitude / 1_000) + "K"
        }

        return sign + "\(Int(magnitude.rounded()))"
    }

    private func trimmedDecimal(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }
}
