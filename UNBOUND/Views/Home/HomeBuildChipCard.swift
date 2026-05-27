// UNBOUND/Views/Home/HomeBuildChipCard.swift
import SwiftUI

struct HomeBuildChipCard: View {
    let profile: AttributeProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AttributeHex(
                    current: profile.hexChartValues,
                    peak: nil,
                    prestigeGlow: profile.prestigeGlowValues,
                    showLabels: false,
                    radius: 38
                )
                .padding(4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("BUILD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(buildPrimary)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color.unbound.textPrimary)
                    if let suffix = buildSuffix {
                        Text(suffix)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.unbound.accent.opacity(0.10), radius: 6)
        }
        .buttonStyle(.plain)
    }

    private var buildPrimary: String {
        // "Power-leaning" — drop the "Hybrid" suffix for one-line header on the chip.
        let parts = profile.buildName.split(separator: " ")
        return parts.first.map(String.init) ?? profile.buildName
    }

    private var buildSuffix: String? {
        if profile.buildName == "Balanced" { return nil }
        return "Hybrid"
    }
}
