// UNBOUND/Views/Profile/ProfileBuildCard.swift
import SwiftUI

struct ProfileBuildCard: View {
    let profile: AttributeProfile

    @State private var selectedKey: AttributeKey?

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 12) {
            Text("BUILD HEX")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 8) {
                AttributeHex(
                    current: profile.hexChartValues,
                    peak: profile.peakHexChartValues,
                    levels: profile.levels,
                    tiers: profile.levelRankTitles,
                    prestigeGlow: profile.prestigeGlowValues,
                    showLabels: true,
                    labelVariant: .profile,
                    radius: 90
                )
                .padding(.horizontal, 40)
                .padding(.vertical, 46)

                Text(profile.buildName.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)

                Text("TAP A STAT FOR DETAILS")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    BuildAttributeCell(
                        key: key,
                        value: profile.value(for: key),
                        isSelected: selectedKey == key
                    ) {
                        selectedKey = key
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(primaryTint.opacity(0.36), lineWidth: 1)
        )
        .sheet(isPresented: Binding(
            get: { selectedKey != nil },
            set: { if !$0 { selectedKey = nil } }
        )) {
            if let selectedKey {
                AttributeInfoSheet(key: selectedKey, value: profile.value(for: selectedKey))
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var dominantKey: AttributeKey { profile.dominant }
    private var primaryTint: Color { dominantKey.rewardTint }
}

private struct AttributeInfoSheet: View {
    let key: AttributeKey
    let value: AttributeValue

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Hexagon()
                        .fill(key.rewardTint.opacity(0.18))
                    Hexagon()
                        .stroke(key.rewardTint.opacity(0.62), lineWidth: 1)
                    VStack(spacing: 1) {
                        Text(key.shortCode)
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        Text("LVL \(value.level)")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        AttributeRankBadge(rank: value.levelRankTitle, size: 12)
                    }
                    .tracking(0)
                    .foregroundStyle(Color.unbound.textPrimary)
                }
                .frame(width: 38, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(key.displayName.uppercased()) LVL \(value.level)")
                        .font(Font.unbound.titleS)
                        .tracking(0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        AttributeRankBadge(rank: value.levelRankTitle, size: 16)
                        Text("\(xpString(value.xpToNextLevel)) XP TO NEXT LEVEL")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.4)
                            .foregroundStyle(value.levelRankTitle.rewardTextTint.opacity(0.92))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(value.levelRankTitle.displayName) rank, \(xpString(value.xpToNextLevel)) XP to next level")
                }

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
            }

            Text(statMeaning)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            levelProgress

            VStack(alignment: .leading, spacing: 10) {
                Text("INFLUENCED BY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)

                ForEach(key.emphasisLifts, id: \.self) { lift in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(key.rewardTint)
                            .frame(width: 5, height: 5)
                        Text(lift.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textPrimary)
                    }
                }
            }

            insightMetric(label: "SCORE", value: "\(Int(value.current.rounded()))")

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.unbound.bg)
    }

    private var levelProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PROGRESS")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("LVL \(value.level)  →  \(value.level + 1)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }

            Rectangle()
                .fill(Color.unbound.surface)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(key.rewardTint)
                            .frame(width: geo.size.width * CGFloat(progressFraction))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text("\(xpString(xpIntoLevel)) / \(xpString(xpSpanForLevel)) XP  ·  \(xpString(value.xpToNextLevel)) TO NEXT")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
        }
    }

    private var progressFraction: Double {
        AttributeLevelCurve.progressFraction(forXP: value.xp)
    }

    private var xpIntoLevel: Double {
        max(0, value.xp - AttributeLevelCurve.xpRequired(forLevel: value.level))
    }

    private var xpSpanForLevel: Double {
        max(0, value.nextLevelXP - AttributeLevelCurve.xpRequired(forLevel: value.level))
    }

    private func xpString(_ xp: Double) -> String {
        let rounded = Int(xp.rounded())
        guard rounded >= 1_000 else { return "\(rounded)" }
        return String(format: "%.1fk", Double(rounded) / 1_000.0)
    }

    private func insightMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .tracking(0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var statMeaning: String {
        switch key {
        case .power:
            return "Raw force output. This rises when heavy strength work improves."
        case .vitality:
            return "Recovery consistency. Easy walks, deloads, and check-ins feed this without judging high-step days."
        case .control:
            return "Body control under tension. Skill work, tempo reps, and clean positions feed this."
        case .endurance:
            return "Your ability to sustain work across longer efforts and higher-density sessions."
        case .mobility:
            return "Usable range of motion. Flexibility only counts when you can control the position."
        case .explosiveness:
            return "Fast force production. Jumps, dynamic reps, and powerful accelerations feed this."
        }
    }
}
