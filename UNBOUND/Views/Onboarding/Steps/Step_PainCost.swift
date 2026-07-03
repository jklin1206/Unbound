import SwiftUI

// MARK: - Step_PainCost
//
// Cinematic pain beat between the opening video and the game hook, framed as
// the first SYSTEM transmission (same bracketed voice as the Home hero).
// Centered kinetic typography - each line punches in with a haptic, naming
// the cost of the restart loop, then the accent line flips the frame:
// "The loop breaks." problemFrame's game question lands next as the answer.
//
// Tap while the sequence is running reveals everything instantly; tap after
// it settles advances. No progress bar, no back - this is a story frame.

struct Step_PainCost: View {
    let onContinue: () -> Void

    @State private var visibleLines = 0
    @State private var showsBreakLine = false
    @State private var showsTapHint = false
    @State private var sequenceComplete = false

    private var costLines: [String] {
        [
            L10n.onboarding("painCost.line1", defaultValue: "You started before."),
            L10n.onboarding("painCost.line2", defaultValue: "Week one felt strong.\nWeek three went quiet."),
            L10n.onboarding("painCost.line3", defaultValue: "Another year, same body.")
        ]
    }

    private var breakLine: String {
        L10n.onboarding("painCost.break", defaultValue: "The loop breaks.")
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .smoky, intensity: 0.7)
                .ignoresSafeArea()
            ParticleEmitter(config: .embers)
                .opacity(0.12)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 30) {
                Text(L10n.onboarding("painCost.eyebrow", defaultValue: "[ SYSTEM ]"))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.coachCyan)
                    .opacity(visibleLines > 0 ? 1 : 0)

                ForEach(Array(costLines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(visibleLines > index ? 1 : 0)
                        .scaleEffect(visibleLines > index ? 1 : 1.08)
                        .blur(radius: visibleLines > index ? 0 : 5)
                }

                Text(breakLine)
                    .font(Font.unbound.displayM)
                    .foregroundStyle(Color.unbound.accent)
                    .shadow(color: Color.unbound.accent.opacity(0.55), radius: 18)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .opacity(showsBreakLine ? 1 : 0)
                    .scaleEffect(showsBreakLine ? 1 : 1.14)
                    .blur(radius: showsBreakLine ? 0 : 7)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)

            VStack {
                Spacer()
                Text(L10n.onboarding("chapter.tapToContinue", defaultValue: "TAP TO CONTINUE"))
                    .font(Font.unbound.monoS)
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .opacity(showsTapHint ? 0.6 : 0)
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: handleTap)
        .onAppear(perform: runSequence)
        .statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func handleTap() {
        if sequenceComplete {
            UnboundHaptics.heavy()
            onContinue()
        } else {
            // Impatient tap: land every line at once and open the exit.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                visibleLines = costLines.count
                showsBreakLine = true
                showsTapHint = true
            }
            sequenceComplete = true
        }
    }

    private func runSequence() {
        let lineDelays: [Double] = [0.45, 1.5, 2.55]
        for (index, delay) in lineDelays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard !sequenceComplete else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    visibleLines = max(visibleLines, index + 1)
                }
                UnboundHaptics.medium()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.75) {
            guard !sequenceComplete else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                showsBreakLine = true
            }
            UnboundHaptics.heavy()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            guard !sequenceComplete else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                showsTapHint = true
            }
            sequenceComplete = true
        }
    }
}

#Preview {
    Step_PainCost(onContinue: {})
}
