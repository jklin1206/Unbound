// UNBOUND/Views/Profile/ProfileBuildCard.swift
import SwiftUI

struct ProfileBuildCard: View {
    let profile: AttributeProfile

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 12) {
            Text("BUILD")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 8) {
                AttributeHex(
                    current: currentValues,
                    peak: peakValues,
                    showLabels: true,
                    radius: 90
                )
                Text(profile.buildName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    BuildAttributeCell(key: key, value: profile.value(for: key))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.4), lineWidth: 1)
        )
    }

    private var currentValues: [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, profile.value(for: $0).current) })
    }

    private var peakValues: [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, profile.value(for: $0).peak) })
    }
}
