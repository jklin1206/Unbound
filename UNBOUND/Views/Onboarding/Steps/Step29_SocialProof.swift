import SwiftUI

// MARK: - Step 29: Social proof gallery
//
// Three beta logs. Kept intentionally bare so this feels like in-world proof,
// not a generic testimonial carousel.

struct Step29_SocialProof: View {
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private var testimonials: [Testimonial] {
        [
            Testimonial(
                quote: L10n.onboarding("socialProof.testimonial.kai.quote", defaultValue: "I opened it because I wanted to see the next gate light up."),
                name: "Kai",
                role: L10n.onboarding("socialProof.role.betaTester", defaultValue: "Beta Tester"),
                rank: .master,
                rankStart: .initiate,
                months: 2,
                sessions: 28,
                streak: 14,
                focus: L10n.onboarding("socialProof.testimonial.kai.focus", defaultValue: "Rank Climb")
            ),
            Testimonial(
                quote: L10n.onboarding("socialProof.testimonial.mason.quote", defaultValue: "The first week felt like a quest, not another plan I had to babysit."),
                name: "Mason",
                role: L10n.onboarding("socialProof.role.betaTester", defaultValue: "Beta Tester"),
                rank: .veteran,
                rankStart: .initiate,
                months: 3,
                sessions: 36,
                streak: 21,
                focus: L10n.onboarding("socialProof.testimonial.mason.focus", defaultValue: "Day Zero")
            ),
            Testimonial(
                quote: L10n.onboarding("socialProof.testimonial.jalen.quote", defaultValue: "Seeing Initiate on Day Zero made me want to earn the next title."),
                name: "Jalen",
                role: L10n.onboarding("socialProof.role.betaTester", defaultValue: "Beta Tester"),
                rank: .forged,
                rankStart: .initiate,
                months: 1,
                sessions: 18,
                streak: 9,
                focus: L10n.onboarding("socialProof.testimonial.jalen.focus", defaultValue: "First Arc")
            )
        ]
    }

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("socialProof.title", defaultValue: "Other players crossed the first gate."),
            subtitle: L10n.onboarding("socialProof.subtitle", defaultValue: "The hook was simple: open the app, do the work, watch the path change."),
            progress: progress,
            primaryTitle: L10n.onboarding("socialProof.primary", defaultValue: "Show me mine"),
            hudStep: .socialProofGallery,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 14) {
                betaHero

                VStack(spacing: 0) {
                    ForEach(Array(testimonials.enumerated()), id: \.element.id) { index, t in
                        betaLogRow(t, index: index + 1)
                    }
                }

                socialProofFooter
            }
        }
    }

    private var betaHero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("onboarding_path_beta_logs")
                .resizable()
                .scaledToFill()
                .frame(height: 238)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.64)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.onboarding("socialProof.eyebrow", defaultValue: "BETA LOG"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.accent)
                Text("First arcs. Real climbs.")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(0.18), radius: 18)
    }

    private var socialProofFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text(L10n.onboarding("socialProof.footer", defaultValue: "The point is not more hype. The point is having a path you want to return to."))
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

                    Text(L10n.onboardingFormat("socialProof.quoteFormat", defaultValue: "\"%@\"", t.quote))
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineSpacing(1.5)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)

                    HStack(spacing: 12) {
                        microStat(L10n.onboardingFormat("socialProof.stat.sessions", defaultValue: "%d sessions", t.sessions))
                        microStat(L10n.onboardingFormat("socialProof.stat.streak", defaultValue: "%dd streak", t.streak))
                        microStat(L10n.onboardingFormat("socialProof.stat.months", defaultValue: "%d mo", t.months))
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
            rankMark(t.rank, tint: t.rank.rewardTint)
        }
    }

    private func rankMark(_ value: RankTitle, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(value.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text(shortRankName(value))
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(tint)
                .lineLimit(1)
        }
    }

    private func microStat(_ value: String) -> some View {
        Text(value.uppercased())
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private func shortRankName(_ rank: RankTitle) -> String {
        switch rank {
        case .initiate: return "INIT"
        case .novice: return "NOV"
        case .apprentice: return "APP"
        case .forged: return "FORG"
        case .veteran: return "VET"
        case .master: return "MAS"
        case .vessel: return "VES"
        case .unbound: return "UNB"
        case .ascendant: return "ASC"
        }
    }

    private struct Testimonial: Identifiable {
        let id = UUID()
        let quote: String
        let name: String
        let role: String
        let rank: RankTitle
        let rankStart: RankTitle
        let months: Int
        let sessions: Int
        let streak: Int
        let focus: String
    }
}

#Preview {
    Step29_SocialProof(progress: 0.96, onBack: {}, onContinue: {})
}
