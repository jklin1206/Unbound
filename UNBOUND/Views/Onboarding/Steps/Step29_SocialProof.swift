import SwiftUI

// MARK: - Step 29: Social proof gallery
//
// Three testimonial cards. Stacked vertically for readability on mobile.

struct Step29_SocialProof: View {
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var selectedIndex: Int = 0

    private let testimonials: [Testimonial] = [
        Testimonial(
            quote: "Rank E to B in 6 months. First time I've actually tracked real change instead of vibes.",
            name: "Marcus",
            age: "19",
            rank: "B",
            rankStart: "E",
            months: 6,
            focus: "Upper Body"
        ),
        Testimonial(
            quote: "The scan showed me exactly what was holding me back. 90 days later my shoulders finally look like shoulders.",
            name: "David",
            age: "23",
            rank: "C",
            rankStart: "E",
            months: 3,
            focus: "Shoulders"
        ),
        Testimonial(
            quote: "I don't look like the same kid. The plan just works when you follow it.",
            name: "Jamal",
            age: "17",
            rank: "C",
            rankStart: "E",
            months: 4,
            focus: "Full Frame"
        )
    ]

    var body: some View {
        OnboardingScaffold(
            title: "This works when you run the protocol.",
            subtitle: "Same system you're about to enter. Real ranks. Real timelines.",
            progress: progress,
            primaryTitle: "I'm in",
            hudStep: .socialProofGallery,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("SUCCESS LOG")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.accent)
                    Text("\(testimonials.count) CASES")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.unbound.surface.opacity(0.9))
                        )
                        .overlay(
                            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }
                .padding(.bottom, 4)

                TabView(selection: $selectedIndex) {
                    ForEach(Array(testimonials.enumerated()), id: \.element.id) { index, t in
                        testimonialCard(t)
                            .tag(index)
                            .padding(.horizontal, 2)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)

                HStack(spacing: 6) {
                    ForEach(testimonials.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == selectedIndex ? Color.unbound.accent : Color.unbound.borderSubtle)
                            .frame(width: index == selectedIndex ? 18 : 8, height: 4)
                            .animation(.easeInOut(duration: 0.25), value: selectedIndex)
                    }
                }

                socialProofFooter
            }
        }
    }

    private func testimonialCard(_ t: Testimonial) -> some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.unbound.accent)
                    }
                    Spacer(minLength: 0)
                    Text("\(t.months) MO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.unbound.surfaceElevated.opacity(0.9))
                        )
                        .overlay(
                            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }

                Text("\"\(t.quote)\"")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.unbound.surfaceElevated)
                        .overlay(
                            Text(String(t.name.prefix(1)))
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.textPrimary)
                        )
                        .frame(width: 32, height: 32)
                    Text("\(t.name), \(t.age)")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Spacer()
                    Text(t.focus.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Rectangle()
                    .fill(Color.unbound.borderSubtle)
                    .frame(height: 0.5)

                HStack(spacing: 8) {
                    progressPill(label: "START", value: t.rankStart, tint: Color.unbound.rankRed)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                    progressPill(label: "NOW", value: t.rank, tint: rankTint(for: t.rank))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var socialProofFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text("Your plan uses your scan + inputs, not generic templates.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func progressPill(label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
            TierBadge(tier: RankTitle.legacyLetterFallback(value).asSkillTier, compact: true)
                .frame(width: 26, height: 26)
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(tint.opacity(0.34), lineWidth: 1)
        )
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
        let age: String
        let rank: String
        let rankStart: String
        let months: Int
        let focus: String
    }
}

#Preview {
    Step29_SocialProof(progress: 0.96, onBack: {}, onContinue: {})
}
