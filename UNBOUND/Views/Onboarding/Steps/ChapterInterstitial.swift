import SwiftUI

struct ChapterInterstitial: View {
    let number: String
    let title: String
    let message: String
    let onContinue: () -> Void

    @State private var revealNumber = false
    @State private var revealTitle = false
    @State private var revealBody = false
    @State private var speedTrigger = UUID()
    @State private var didAutoAdvance = false

    private let autoAdvanceAfter: Double = 2.8

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .smoky, intensity: 1.1)
                .ignoresSafeArea()
            TechGridBackground(opacity: 0.22)
                .ignoresSafeArea()

            SpeedLines(
                count: 28,
                length: 160,
                innerRadius: 80,
                color: Color.unbound.accent,
                burstDuration: 0.6,
                trigger: speedTrigger
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ParticleEmitter(config: .embers)
                .opacity(0.45)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 22) {
                Text(number)
                    .font(Font.unbound.displayL)
                    .tracking(3)
                    .foregroundStyle(Color.unbound.accent)
                    .shadow(color: Color.unbound.accent.opacity(0.6), radius: 18)
                    .opacity(revealNumber ? 1 : 0)
                    .scaleEffect(revealNumber ? 1 : 0.92)
                    .blur(radius: revealNumber ? 0 : 6)

                Text(title)
                    .font(Font.unbound.titleL)
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .shadow(color: Color.unbound.accent.opacity(0.35), radius: 14)
                    .opacity(revealTitle ? 1 : 0)
                    .offset(y: revealTitle ? 0 : 8)

                Text(message)
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(revealBody ? 1 : 0)
                    .offset(y: revealBody ? 0 : 8)
            }

            VStack {
                Spacer()
                Text("TAP TO CONTINUE")
                    .font(Font.unbound.monoS)
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .opacity(revealBody ? 0.6 : 0)
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !didAutoAdvance else { return }
            didAutoAdvance = true
            UnboundHaptics.heavy()
            onContinue()
        }
        .onAppear {
            UnboundHaptics.heavy()
            speedTrigger = UUID()

            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                revealNumber = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    revealTitle = true
                }
                UnboundHaptics.medium()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                withAnimation(.easeOut(duration: 0.4)) {
                    revealBody = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + autoAdvanceAfter) {
                guard !didAutoAdvance else { return }
                didAutoAdvance = true
                onContinue()
            }
        }
        .statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    ChapterInterstitial(
        number: "CHAPTER II",
        title: "THE MAPPING",
        message: "We map who you are. Answer true.",
        onContinue: {}
    )
}
