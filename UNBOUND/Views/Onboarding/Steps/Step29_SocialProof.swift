import SwiftUI

// MARK: - Step 29: Social proof gallery
//
// Three beta logs. Kept intentionally bare so this feels like in-world proof,
// not a generic testimonial carousel.

struct Step29_SocialProof: View {
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var hasAnimated = false

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
            title: L10n.onboarding("socialProof.title", defaultValue: "Others started at the floor too."),
            subtitle: L10n.onboarding("socialProof.subtitle", defaultValue: "They opened the gate, cleared sessions, and watched the ladder stop being decoration."),
            progress: progress,
            primaryTitle: L10n.onboarding("socialProof.primary", defaultValue: "Reveal the ladder"),
            hudStep: .socialProofGallery,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 14) {
                betaHero

                VStack(spacing: 12) {
                    ForEach(Array(testimonials.enumerated()), id: \.element.id) { index, t in
                        climberProfileCard(t, index: index + 1)
                            .opacity(hasAnimated ? 1 : 0)
                            .offset(y: hasAnimated ? 0 : 18)
                            .animation(.spring(response: 0.5, dampingFraction: 0.86).delay(0.14 + Double(index) * 0.08), value: hasAnimated)
                    }
                }

                socialProofFooter
            }
            .onAppear {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) {
                    hasAnimated = true
                }
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
                Text(L10n.onboarding("socialProof.hero.title", defaultValue: "First arcs. Real climbs."))
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
            Text(L10n.onboarding("socialProof.footer", defaultValue: "The win is not the quote. The win is that the next rank gives the work somewhere to go."))
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    private func climberProfileCard(_ t: Testimonial, index: Int) -> some View {
        let tint = profileTint(for: t.rank)

        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 12) {
                profileAvatar(t, index: index, tint: tint)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(t.name.uppercased())
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)

                        Text(t.role.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(0.9)
                            .foregroundStyle(tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(tint.opacity(0.12)))
                            .overlay(Capsule().strokeBorder(tint.opacity(0.32), lineWidth: 1))
                    }

                    Text(t.focus.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer(minLength: 0)
            }

            premiumRankMove(t, tint: tint)

            Text(L10n.onboardingFormat("socialProof.quoteFormat", defaultValue: "\"%@\"", t.quote))
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.88))
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                profileStat(value: "\(t.sessions)", label: "SESSIONS", tint: tint)
                profileStat(value: "\(t.streak)d", label: "STREAK", tint: tint)
                profileStat(value: "\(t.months)mo", label: "CLIMB", tint: tint)
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                LinearGradient(
                    colors: [
                        tint.opacity(0.18),
                        Color.unbound.surface.opacity(0.78),
                        Color.black.opacity(0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [tint.opacity(0.68), Color.white.opacity(0.08), tint.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
        .shadow(color: tint.opacity(0.18), radius: 18, y: 8)
    }

    private func profileAvatar(_ t: Testimonial, index: Int, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.46), Color.unbound.surface.opacity(0.92)],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 54
                    )
                )

            Circle()
                .strokeBorder(tint.opacity(0.72), lineWidth: 1.4)

            Text(String(t.name.prefix(1)).uppercased())
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.unbound.textPrimary)

            Text(String(format: "%02d", index))
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.bg)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(tint))
                .offset(x: 22, y: 23)
        }
        .frame(width: 58, height: 58)
        .shadow(color: tint.opacity(0.42), radius: 14)
    }

    private func premiumRankMove(_ t: Testimonial, tint: Color) -> some View {
        HStack(spacing: 9) {
            rankBubble(label: "START", rank: t.rankStart, tint: Color.unbound.textTertiary)

            ZStack {
                Capsule()
                    .fill(tint.opacity(0.12))
                    .frame(width: 34, height: 22)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(tint)
            }

            rankBubble(label: "NOW", rank: t.rank, tint: tint)
        }
    }

    private func rankBubble(label: String, rank: RankTitle, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(rank.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .shadow(color: tint.opacity(0.36), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(rankDisplayName(rank))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.32), lineWidth: 1)
        )
    }

    private func profileStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value.uppercased())
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
    }

    private func profileTint(for rank: RankTitle) -> Color {
        switch rank {
        case .initiate, .novice:
            return Color.unbound.accent
        case .apprentice, .forged:
            return Color.unbound.warnOrange
        case .veteran:
            return Color.unbound.rankGreen
        case .master:
            return Color.unbound.impact
        case .vessel, .unbound, .ascendant:
            return rank.rewardTint
        }
    }

    private func rankDisplayName(_ rank: RankTitle) -> String {
        switch rank {
        case .initiate: return "INITIATE"
        case .novice: return "NOVICE"
        case .apprentice: return "APPRENTICE"
        case .forged: return "FORGED"
        case .veteran: return "VETERAN"
        case .master: return "MASTER"
        case .vessel: return "VESSEL"
        case .unbound: return "UNBOUND"
        case .ascendant: return "ASCENDANT"
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
