import SwiftUI

// MARK: - BodyTierView
//
// Hero body view displaying per-muscle-group tier ranks. Inspired by the
// reference we're chasing (Chest TITAN / Core DIAMOND / Legs TITAN style)
// but holding UNBOUND's brand discipline: monochrome surface, violet
// reserved for rank signals, Geist Mono readouts.
//
// Data: [MuscleGroupTierState] — one per muscle group the calculator
// knows about. Front-view shows the 6 primary front-visible groups as
// floating chips around a stylized silhouette. A compact legend lists
// the rest below.
//
// This is a standalone "where you stand" screen. Share card wiring is
// a later chunk (Chunk 7).

struct BodyTierView: View {
    let states: [MuscleGroupTierState]

    /// Quick lookup.
    private var byGroup: [MuscleGroup: MuscleGroupTierState] {
        Dictionary(uniqueKeysWithValues: states.map { ($0.muscleGroup, $0) })
    }

    /// The 6 muscle groups rendered as floating chips on the front-view
    /// silhouette. Back-view groups (back, lats, traps, glutes, calves,
    /// neck) show in the legend below.
    private let frontGroups: [MuscleGroup] = [
        .shoulders, .chest, .arms, .forearms, .core, .legs
    ]

    private var otherGroups: [MuscleGroup] {
        MuscleGroup.allCases.filter { !frontGroups.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                silhouetteWithChips
                overallRow
                legendSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("YOUR BODY")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.2)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where you stand")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Tier by muscle group. Updates with every scan and lift.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Silhouette + chips

    private var silhouetteWithChips: some View {
        ZStack {
            // Silhouette (SF Symbol placeholder — replaced with archetype art later)
            Image(systemName: "figure.arms.open")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(height: 340)
                .padding(.vertical, 16)

            // Floating chips — positioned via alignment grid
            GeometryReader { geo in
                ForEach(frontGroups, id: \.self) { group in
                    chipFor(group)
                        .position(chipPosition(for: group, in: geo.size))
                }
            }
            .frame(height: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    /// Rough anatomical positions for the 6 front-view chips. Values are
    /// normalized to the container size and tuned visually — not
    /// pixel-perfect to anatomy, just positionally readable.
    private func chipPosition(for group: MuscleGroup, in size: CGSize) -> CGPoint {
        let w = size.width
        let h = size.height
        switch group {
        case .shoulders: return .init(x: w * 0.12, y: h * 0.25)
        case .chest:     return .init(x: w * 0.87, y: h * 0.32)
        case .arms:      return .init(x: w * 0.12, y: h * 0.48)
        case .forearms:  return .init(x: w * 0.87, y: h * 0.55)
        case .core:      return .init(x: w * 0.12, y: h * 0.70)
        case .legs:      return .init(x: w * 0.87, y: h * 0.82)
        default:         return .init(x: w * 0.5, y: h * 0.5)
        }
    }

    private func chipFor(_ group: MuscleGroup) -> some View {
        let state = byGroup[group]
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(Font.unbound.captionS)
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(state?.tier.letter ?? "—")
                    .font(Font.unbound.monoL)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            if let tier = state?.tier {
                MiniRankBadge(letter: tier.letter)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    // MARK: Overall row

    private var overallRow: some View {
        let avg = states.isEmpty ? 0 : states.map(\.score).reduce(0, +) / states.count
        let overallTier = MuscleGroupTier.from(score: avg)
        return HStack(spacing: 14) {
            RankBadge(letter: overallTier.letter, size: .medium)
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall tier")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(overallTier.caption)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Average of \(states.count) tracked groups")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(avg)")
                    .font(Font.unbound.monoL)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("SCORE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    // MARK: Legend / remainder

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ALL MUSCLE GROUPS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2)
                .foregroundStyle(Color.unbound.textSecondary)

            VStack(spacing: 8) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    legendRow(for: group)
                }
            }
        }
    }

    private func legendRow(for group: MuscleGroup) -> some View {
        let state = byGroup[group]
        return HStack(spacing: 12) {
            Text(group.displayName)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 100, alignment: .leading)
            // Score progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.border)
                    Capsule()
                        .fill(Color.unbound.accent.opacity(0.85))
                        .frame(width: max(4, geo.size.width * (Double(state?.score ?? 0) / 100)))
                }
            }
            .frame(height: 4)
            Text("\(state?.score ?? 0)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 32, alignment: .trailing)
            MiniRankBadge(letter: state?.tier.letter ?? "—")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }
}

// MARK: - MiniRankBadge
//
// Small inline version of the Hexagon RankBadge. Used in tier chips and
// muscle-group legend rows where the large RankBadge would dominate.

struct MiniRankBadge: View {
    let letter: String
    var side: CGFloat = 30

    var body: some View {
        ZStack {
            Hexagon().fill(Color.unbound.surfaceElevated)
            Hexagon().strokeBorder(Color.unbound.accent, lineWidth: 1.25)
                .shadow(color: Color.unbound.accent.opacity(0.45), radius: 4)
            Text(letter)
                .font(.system(size: side * 0.42, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
        }
        .frame(width: side, height: side)
    }
}

// MARK: - Preview

#Preview("Body Tier — sample") {
    NavigationStack {
        BodyTierView(states: MuscleGroupTierState.previewSample)
    }
    .preferredColorScheme(.dark)
}

extension MuscleGroupTierState {
    static let previewSample: [MuscleGroupTierState] = [
        .init(userId: "preview", muscleGroup: .chest,     tier: .a, score: 82, scanBaseline: 78, logBoost: 4, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .back,      tier: .b, score: 71, scanBaseline: 70, logBoost: 1, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .shoulders, tier: .b, score: 68, scanBaseline: 65, logBoost: 3, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .arms,      tier: .c, score: 58, scanBaseline: 56, logBoost: 2, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .forearms,  tier: .c, score: 52, scanBaseline: 50, logBoost: 2, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .legs,      tier: .s, score: 92, scanBaseline: 88, logBoost: 4, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .glutes,    tier: .b, score: 74, scanBaseline: 72, logBoost: 2, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .core,      tier: .a, score: 81, scanBaseline: 80, logBoost: 1, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .traps,     tier: .d, score: 42, scanBaseline: 42, logBoost: 0, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .neck,      tier: .e, score: 25, scanBaseline: 25, logBoost: 0, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .lats,      tier: .b, score: 70, scanBaseline: 68, logBoost: 2, updatedAt: .now),
        .init(userId: "preview", muscleGroup: .calves,    tier: .d, score: 38, scanBaseline: 38, logBoost: 0, updatedAt: .now)
    ]
}
