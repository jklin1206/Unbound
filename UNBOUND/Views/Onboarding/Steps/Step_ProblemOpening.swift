import SwiftUI

// MARK: - Step_ProblemFrame
//
// The hook beat: "what if training played like a game?" Storytelling, not a
// stat sheet — a dormant silhouette and three lines that set the world's
// terms, cascading in like system text. The game itself starts on the NEXT
// screen (restartLoop's build preview, then arc03's ranks), so this screen
// shows neither.

struct Step_ProblemFrame: View {
    let onContinue: () -> Void

    @State private var hasAnimated = false
    @State private var visibleLines = 0

    // Continues the SYSTEM's voice from the cost beat: names why the old way
    // never held (no stakes), then hands into the game. Two tight lines; any
    // more reads as a wall of text under the silhouette.
    private var storyLines: [String] {
        [
            L10n.onboarding("problemOpening.story.silence", defaultValue: "No rank. No proof. Not yet."),
            L10n.onboarding("problemOpening.story.stakes", defaultValue: "That changes the moment you begin.")
        ]
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .godRay, intensity: 0.78)
                .ignoresSafeArea()
            ParticleEmitter(config: .embers)
                .opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 44)

                VStack(spacing: 9) {
                    Text(L10n.onboarding("problemOpening.eyebrow", defaultValue: "[ SYSTEM ]"))
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(Color.unbound.coachCyan)

                    Text(L10n.onboarding("problemOpening.title", defaultValue: "Right now, you are no one here."))
                        .font(Font.unbound.displayM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                }
                .padding(.horizontal, 24)
                .opacity(hasAnimated ? 1 : 0)

                Spacer(minLength: 8)

                SilhouetteView(
                    rimLight: .dim,
                    chromaticAberration: 0.38,
                    breathe: true,
                    scale: 0.86,
                    asset: .dormant
                )
                .frame(width: 200, height: 380)
                .opacity(hasAnimated ? 1 : 0)

                Spacer(minLength: 8)

                VStack(alignment: .center, spacing: 10) {
                    ForEach(Array(storyLines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(Font.unbound.bodyL.weight(.semibold))
                            .foregroundStyle(Color.unbound.textPrimary.opacity(0.94))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
                            .opacity(visibleLines > index ? 1 : 0)
                            .offset(y: visibleLines > index ? 0 : 10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 28)

                Spacer(minLength: 20)

                UnboundButton(title: L10n.onboarding("problemOpening.cta", defaultValue: "Change the game"), icon: "arrow.right", action: onContinue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .opacity(visibleLines >= storyLines.count ? 1 : 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.86).delay(0.12)) {
                hasAnimated = true
            }
            for index in 0..<storyLines.count {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.55 + Double(index) * 0.5)) {
                    visibleLines = index + 1
                }
            }
        }
    }
}
