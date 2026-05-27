// UNBOUND/Views/Scan/ScanBuildDeltaCard.swift
import SwiftUI

struct ScanBuildDeltaCard: View {
    let firstScan: AttributeProfile
    let latestScan: AttributeProfile

    var body: some View {
        VStack(spacing: 12) {
            Text(L10n.string(.scanBuildDeltaTitle, defaultValue: "BUILD · ARC EVOLUTION"))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)

            HStack(spacing: 8) {
                Text(firstScan.buildName)
                    .foregroundStyle(Color.unbound.textTertiary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                Text(latestScan.buildName)
                    .foregroundStyle(Color.unbound.accent)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 13))

            HStack(alignment: .center, spacing: 10) {
                VStack(spacing: 4) {
                    Text(L10n.string(.scanBuildDeltaFirstScan, defaultValue: "SCAN 1"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                    AttributeHex(current: values(firstScan), peak: nil, showLabels: false, radius: 54)
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                VStack(spacing: 4) {
                    Text(L10n.string(.scanBuildDeltaLatest, defaultValue: "LATEST"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.accent)
                    AttributeHex(current: values(latestScan), peak: nil, showLabels: false, radius: 54)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    deltaCell(for: key)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.unbound.accent.opacity(0.4), lineWidth: 1))
    }

    private func values(_ p: AttributeProfile) -> [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, p.value(for: $0).current) })
    }

    private func deltaCell(for key: AttributeKey) -> some View {
        let delta = latestScan.value(for: key).current - firstScan.value(for: key).current
        let rounded = Int(delta.rounded())
        let didImprove = rounded > 0
        return VStack(spacing: 2) {
            Text(didImprove ? "+\(rounded)" : "HELD")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(didImprove ? Color.unbound.accent : Color.unbound.textTertiary)
            Text(key.shortCode)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.unbound.bg))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.unbound.border, lineWidth: 1))
    }
}
