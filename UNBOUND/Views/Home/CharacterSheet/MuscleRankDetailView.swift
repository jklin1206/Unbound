import SwiftUI

// MARK: - MuscleRankDetailView
//
// Rank detail screen presented when a muscle is tapped from the heatmap.
// Implements the "always moving" progression UX — letter-rank stays stable,
// sub-rank gives weekly dopamine, underlying score ticks up continuously.
//
// Prevents the "stuck at B" feeling by making forward motion always visible
// via three clocks:
//   1. Letter tier    (slow, cinematic when it changes — the brand moment)
//   2. Sub-rank       (weekly, haptic-only promotions)
//   3. Score 0-100    (per session, continuous)
//
// The A → UNBOUND transition is the single cinematic moment in the system.
// All other tier-ups get a subtle color bloom. Protect the brand moment.

struct MuscleRankDetailView: View {
    let model: MuscleRankDetailModel

    @Environment(\.dismiss) private var dismiss
    @Namespace private var heroBadge

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header
                heroSection
                progressBar
                questsSection
                footerStats
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Text(model.muscleName.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(10)
                    .background(Circle().fill(Color.unbound.surface))
            }
            .buttonStyle(.plain)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 14) {
            RankBadgeView(subRank: model.subRank, tier: model.tier)
                .frame(width: 180, height: 180)
                .matchedGeometryEffect(id: "badge", in: heroBadge)

            Text(model.tier.caption.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(Color.unbound.textSecondary)

            Text("\(model.score) / 100")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var progressBar: some View {
        TierProgressBar(score: model.score)
            .frame(height: 44)
    }

    private var questsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("WHAT GETS YOU TO \(model.nextTier.caption.uppercased())")

            VStack(spacing: 10) {
                ForEach(model.quests) { quest in
                    RankQuestRow(quest: quest)
                }
            }
        }
    }

    private var footerStats: some View {
        VStack(spacing: 10) {
            FooterStatRow(
                label: "THIS WEEK",
                value: model.weekDelta >= 0 ? "+\(model.weekDelta) points" : "\(model.weekDelta) points",
                tint: model.weekDelta > 0 ? Color.unbound.success : Color.unbound.textSecondary
            )
            FooterStatRow(
                label: "LAST RANK-UP",
                value: model.lastRankUpDescription,
                tint: Color.unbound.textSecondary
            )
        }
        .padding(.top, 8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(Color.unbound.textTertiary)
    }
}

// MARK: - Input model
// Detail view consumes a flattened, display-ready model. Build this at the
// call site from MuscleGroupAssessment + WorkoutLog + RankService.

struct MuscleRankDetailModel {
    let muscleName: String
    let score: Int                  // 0...100
    let tier: MuscleGroupTier       // derived from score
    let subRank: SubRank            // includes modifier (E-/E/E+)
    let quests: [RankQuest]         // 3-5 actionable "one rep away" items
    let weekDelta: Int              // +/- points this week
    let lastRankUpDescription: String   // e.g. "B- → B · 18 days ago"

    /// The next letter tier above the current one (caps at .s).
    var nextTier: MuscleGroupTier {
        MuscleGroupTier.allCases.first { $0.rank == min(5, tier.rank + 1) } ?? tier
    }
}

struct RankQuest: Identifiable {
    let id = UUID()
    let title: String               // "Bench 225 × 5"
    let userBest: String?           // "your best: 215 × 5"
    let shortfall: String?          // "1 rep short" — nil when complete
    let isComplete: Bool
}

// MARK: - Rank badge (placeholder — swap for PNG asset once generated)
// For now, a violet-tinted stylized letter + sub-rank pips. When the
// gemini-generated PNG badges land in Assets.xcassets, replace the body
// of this view with `Image("rank-\(tier.rawValue)")` and overlay the pips.

struct RankBadgeView: View {
    let subRank: SubRank
    let tier: MuscleGroupTier

    var body: some View {
        ZStack {
            // TODO: swap for Image("rank-\(tier.rawValue)") when assets land
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(tierColor.gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.unbound.textPrimary.opacity(0.15), lineWidth: 1.5)
                )
                .shadow(color: tierColor.opacity(0.35), radius: 24, y: 12)

            VStack(spacing: 10) {
                Text(tier.letter)
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(letterColor)

                subRankPips
            }
        }
    }

    private var subRankPips: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i <= activePipIndex ? Color.unbound.textPrimary : Color.unbound.textPrimary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var activePipIndex: Int {
        switch subRank.modifier {
        case "-": return 0
        case "+": return 2
        default:  return 1
        }
    }

    private var tierColor: Color {
        switch tier {
        case .e: return Color.unbound.rankRed
        case .d: return Color.unbound.rankOrange
        case .c: return Color.unbound.rankAmber
        case .b: return Color.unbound.rankGreen
        case .a: return Color.unbound.accent          // cursed violet
        case .s: return Color.unbound.rankGold
        }
    }

    private var letterColor: Color {
        // Amber + gold are bright — dark letter reads better.
        switch tier {
        case .c, .s: return Color.unbound.bg
        default:     return Color.unbound.textPrimary
        }
    }
}

// MARK: - Tier progress bar
// Horizontal track with marks at 30 / 50 / 65 / 80 / 90 (the boundaries
// from MuscleGroupTier.from(score:)). Current position highlighted with
// a glowing violet diamond.

struct TierProgressBar: View {
    let score: Int

    private static let thresholds: [Int] = [0, 30, 50, 65, 80, 90, 100]
    private static let letters: [String] = ["E", "D", "C", "B", "A", "S"]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clampedScore = max(0, min(100, score))
            let pct = CGFloat(clampedScore) / 100

            VStack(spacing: 10) {
                // track
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.surface)
                        .frame(height: 10)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.unbound.rankRed, Color.unbound.rankOrange, Color.unbound.rankAmber,
                                         Color.unbound.rankGreen, Color.unbound.accent, Color.unbound.rankGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(w * pct, 10), height: 10)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: score)

                    // current-position marker
                    Circle()
                        .fill(Color.unbound.textPrimary)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.unbound.accent, lineWidth: 3))
                        .shadow(color: Color.unbound.accent.opacity(0.6), radius: 8)
                        .offset(x: max(0, w * pct - 9), y: 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: score)
                }

                // tier letters under each threshold
                ZStack(alignment: .leading) {
                    ForEach(Array(Self.letters.enumerated()), id: \.offset) { i, letter in
                        let midThreshold = CGFloat(Self.thresholds[i] + Self.thresholds[i + 1]) / 2 / 100
                        Text(letter)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.unbound.textTertiary)
                            .offset(x: w * midThreshold - 6)
                    }
                }
                .frame(height: 14)
            }
        }
    }
}

// MARK: - Quest row
// One actionable "here's what gets you there" item. Shows the goal, the
// user's current best, and the shortfall phrased as a single rep/lb delta.

struct RankQuestRow: View {
    let quest: RankQuest

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: quest.isComplete ? "checkmark.circle.fill" : "diamond.fill")
                .font(.system(size: 16))
                .foregroundStyle(quest.isComplete ? Color.unbound.success : Color.unbound.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .strikethrough(quest.isComplete, color: Color.unbound.textSecondary)

                if let best = quest.userBest {
                    HStack(spacing: 6) {
                        Text(best)
                            .foregroundStyle(Color.unbound.textSecondary)
                        if let short = quest.shortfall {
                            Text("·")
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text(short)
                                .foregroundStyle(Color.unbound.accent)
                        }
                    }
                    .font(.system(size: 13))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }
}

// MARK: - Footer row

private struct FooterStatRow: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color.unbound.borderSubtle)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Previews

#Preview("Sharpened · B+") {
    MuscleRankDetailView(model: .sharpenedSample)
}

#Preview("Unbound · A-") {
    MuscleRankDetailView(model: .unboundSample)
}

private extension MuscleRankDetailModel {
    static let sharpenedSample = MuscleRankDetailModel(
        muscleName: "Chest",
        score: 77,
        tier: .b,
        subRank: .bPlus,
        quests: [
            RankQuest(
                title: "Bench 225 × 5",
                userBest: "your best: 215 × 5",
                shortfall: "1 rep short",
                isComplete: false
            ),
            RankQuest(
                title: "Weighted dips · 45lb × 6",
                userBest: "your best: bodyweight × 12",
                shortfall: "add weight",
                isComplete: false
            ),
            RankQuest(
                title: "Incline pushups · 10 clean reps",
                userBest: nil,
                shortfall: nil,
                isComplete: true
            ),
        ],
        weekDelta: 3,
        lastRankUpDescription: "B- → B · 18 days ago"
    )

    static let unboundSample = MuscleRankDetailModel(
        muscleName: "Back",
        score: 82,
        tier: .a,
        subRank: .aMinus,
        quests: [
            RankQuest(
                title: "Weighted pull-ups · +45 × 5",
                userBest: "your best: +25 × 5",
                shortfall: "+20lb to go",
                isComplete: false
            ),
        ],
        weekDelta: 4,
        lastRankUpDescription: "B+ → A- · 3 days ago"
    )
}
