import SwiftUI

struct Step_Arc03_Path: View {
    let onBegin: () -> Void

    @State private var statsIn: Bool = false
    @State private var copyIn: Bool = false
    @State private var buttonPulse: Bool = false
    @State private var barPhase: Int = 0

    /// Stat axes — locked 4-stat canon: Strength / Stamina / Technique / Vitality.
    private let statLabels = ["STRENGTH", "STAMINA", "TECHNIQUE", "VITALITY"]

    /// Static rank display — represents the full potential arc, not a single
    /// archetype. Deleted archetype-cycling gallery (Phase 2f). Sub-project #7
    /// owns the full onboarding reframe.
    private let statRanks: [(tier: String, value: Double)] = [
        ("S", 0.92), ("A", 0.85), ("A", 0.80), ("A", 0.82)
    ]

    var body: some View {
        ZStack {
            AnimeBackdrop(variant: .godRay, intensity: 1.0)
                .ignoresSafeArea()

            ParticleEmitter(config: .embers, isActive: true)
                .opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                HStack(alignment: .center, spacing: 18) {
                    // Silhouette column
                    ZStack {
                        SilhouetteView(
                            rimLight: .impact,
                            chromaticAberration: 0.0,
                            breathe: true,
                            scale: 0.85
                        )
                        .frame(width: 190, height: 380)
                    }
                    .opacity(statsIn ? 1 : 0)
                    .offset(y: statsIn ? 0 : 20)

                    // Stat bars column
                    VStack(spacing: 18) {
                        ForEach(Array(statLabels.enumerated()), id: \.offset) { index, label in
                            let rank = statRanks[index]
                            StatBar(
                                label: label,
                                tier: rank.tier,
                                value: rank.value,
                                animate: true,
                                muted: false,
                                startDelay: 0.55 + Double(index) * 0.15
                            )
                            .onAppear { schedHaptic(index, delay: 0.6 + Double(index) * 0.15) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(statsIn ? 1 : 0)
                    .offset(y: statsIn ? 0 : 16)
                }
                .padding(.horizontal, 20)

                Text("Your version of strong")
                    .font(Font.unbound.captionS)
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .textCase(.uppercase)
                    .opacity(copyIn ? 1 : 0)
                    .padding(.top, 20)

                Spacer()

                VStack(spacing: 12) {
                    Text("Your training arc starts now")
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .tracking(0.2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text("Every rep ranked. Every arc measured.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }
                .padding(.horizontal, 28)
                .opacity(copyIn ? 1 : 0)
                .offset(y: copyIn ? 0 : 12)

                Spacer().frame(height: 24)

                UnboundButton(title: "Begin", icon: "arrow.right", action: onBegin)
                    .opacity(copyIn ? 1 : 0)
                    .scaleEffect(buttonPulse ? 1.02 : 1.0)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                statsIn = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(1.2)) {
                copyIn = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(1.4)) {
                buttonPulse = true
            }
        }
    }

    // MARK: - Helpers

    @State private var haptTicked: [Bool] = [false, false, false, false]

    private func schedHaptic(_ index: Int, delay: Double) {
        guard !haptTicked[index] else { return }
        haptTicked[index] = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UnboundHaptics.medium()
        }
    }
}

#Preview {
    Step_Arc03_Path(onBegin: {})
}
