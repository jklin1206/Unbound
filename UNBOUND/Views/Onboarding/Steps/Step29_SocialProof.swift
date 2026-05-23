import SwiftUI

// MARK: - Step 29: Social proof gallery
//
// Three beta logs. Kept intentionally bare so this feels like in-world proof,
// not a generic testimonial carousel.

struct Step29_SocialProof: View {
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private let testimonials: [Testimonial] = [
        Testimonial(
            quote: "I stopped negotiating with myself. I wanted to see the card move.",
            name: "Kai",
            role: "Beta Tester",
            rank: "B",
            rankStart: "E",
            months: 2,
            sessions: 28,
            streak: 14,
            focus: "Rank Climb"
        ),
        Testimonial(
            quote: "Day Zero made the first week feel real. Every workout had a reason.",
            name: "Mason",
            role: "Beta Tester",
            rank: "C",
            rankStart: "E",
            months: 3,
            sessions: 36,
            streak: 21,
            focus: "Day Zero"
        ),
        Testimonial(
            quote: "It felt like loading into a training arc. I actually wanted the next session.",
            name: "Jalen",
            role: "Beta Tester",
            rank: "C",
            rankStart: "E",
            months: 1,
            sessions: 18,
            streak: 9,
            focus: "First Arc"
        )
    ]

    var body: some View {
        OnboardingScaffold(
            title: "They came back for the next session.",
            subtitle: "Beta testers started at Day Zero and kept opening UNBOUND because the climb felt visible.",
            progress: progress,
            primaryTitle: "I'm in",
            hudStep: .socialProofGallery,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("BETA LOG")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.accent)
                }
                .padding(.bottom, 4)

                VStack(spacing: 0) {
                    ForEach(Array(testimonials.enumerated()), id: \.element.id) { index, t in
                        betaLogRow(t, index: index + 1)
                    }
                }

                socialProofFooter
            }
        }
    }

    private var socialProofFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text("Open the app. Finish the session. Watch the rank move.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    private func betaLogRow(_ t: Testimonial, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: "%02d", index))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.accent)

                    compactRankMove(t)
                }
                .frame(width: 86, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(t.name)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)

                        Text(t.role.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(0.9)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }

                    Text("\"\(t.quote)\"")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineSpacing(1.5)
                        .lineLimit(3)
                        .minimumScaleFactor(0.88)

                    HStack(spacing: 12) {
                        microStat("\(t.sessions) sessions")
                        microStat("\(t.streak)d streak")
                        microStat("\(t.months) mo")
                    }
                }
            }
            .padding(.vertical, 17)

            Rectangle()
                .fill(Color.unbound.borderSubtle.opacity(0.72))
                .frame(height: 1)
        }
        .overlay(
            Rectangle()
                .fill(Color.unbound.accent.opacity(0.34))
                .frame(width: 2),
            alignment: .leading
        )
    }

    private func compactRankMove(_ t: Testimonial) -> some View {
        HStack(spacing: 5) {
            rankMark(t.rankStart, tint: Color.unbound.textTertiary)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.unbound.textTertiary)
            rankMark(t.rank, tint: rankTint(for: t.rank))
        }
    }

    private func rankMark(_ value: String, tint: Color) -> some View {
        let tier = RankTitle.legacyLetterFallback(value).asSkillTier
        return HStack(spacing: 4) {
            Image(tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
        }
    }

    private func microStat(_ value: String) -> some View {
        Text(value.uppercased())
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private func rankTint(for letter: String) -> Color {
        switch letter.uppercased() {
        case "S": return Color.unbound.rankGold
        case "A": return Color.unbound.accent
        case "B": return Color.unbound.rankGreen
        case "C": return Color.unbound.rankGreen
        case "D": return Color.unbound.rankOrange
        default: return Color.unbound.rankRed
        }
    }

    private struct Testimonial: Identifiable {
        let id = UUID()
        let quote: String
        let name: String
        let role: String
        let rank: String
        let rankStart: String
        let months: Int
        let sessions: Int
        let streak: Int
        let focus: String
    }
}

#Preview {
    Step29_SocialProof(progress: 0.96, onBack: {}, onContinue: {})
}
