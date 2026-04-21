import SwiftUI

// MARK: - Step 29: Social proof gallery
//
// Three testimonial cards. Stacked vertically for readability on mobile.

struct Step29_SocialProof: View {
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private let testimonials: [Testimonial] = [
        Testimonial(
            quote: "Rank E to B in 6 months. First time I've actually tracked real change instead of vibes.",
            name: "Marcus",
            age: "19",
            rank: "B"
        ),
        Testimonial(
            quote: "The scan showed me exactly what was holding me back. 90 days later my shoulders finally look like shoulders.",
            name: "David",
            age: "23",
            rank: "C"
        ),
        Testimonial(
            quote: "I don't look like the same kid. The plan just works when you follow it.",
            name: "Jamal",
            age: "17",
            rank: "C"
        )
    ]

    var body: some View {
        OnboardingScaffold(
            title: "You're not alone.",
            subtitle: "Real people, real protocols, real change.",
            progress: progress,
            primaryTitle: "Continue",
            hudStep: .socialProofGallery,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 14) {
                ForEach(testimonials) { t in
                    testimonialCard(t)
                }
            }
        }
    }

    private func testimonialCard(_ t: Testimonial) -> some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.unbound.accent)
                    }
                }
                Text("\"\(t.quote)\"")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
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
                    HStack(spacing: 6) {
                        Text("Now:")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                        RankBadge(letter: t.rank, size: .small)
                    }
                }
            }
        }
    }

    private struct Testimonial: Identifiable {
        let id = UUID()
        let quote: String
        let name: String
        let age: String
        let rank: String
    }
}

#Preview {
    Step29_SocialProof(progress: 0.96, onBack: {}, onContinue: {})
}
