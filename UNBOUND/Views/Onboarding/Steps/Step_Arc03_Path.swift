import SwiftUI

struct Step_Arc03_Path: View {
    let onBegin: () -> Void

    @State private var silhouetteIn: Bool = false
    @State private var statsIn: Bool = false
    @State private var copyIn: Bool = false
    @State private var archetypeIndex: Int = 0
    @State private var buttonPulse: Bool = false
    @State private var haptTicked: [Bool] = [false, false, false, false]

    private let archetypes = Archetype.allCases.map(\.shortName)

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
                    ZStack {
                        TimelineView(.animation(minimumInterval: 0.8)) { ctx in
                            let raw = ctx.date.timeIntervalSinceReferenceDate
                            let idx = Int(raw) % archetypes.count
                            Text(archetypes[idx])
                                .font(Font.unbound.captionS)
                                .tracking(1.6)
                                .foregroundStyle(Color.unbound.textTertiary.opacity(0.55))
                                .textCase(.uppercase)
                                .offset(y: -140)
                                .id(idx)
                                .transition(.opacity)
                        }

                        SilhouetteView(
                            rimLight: .impact,
                            chromaticAberration: 0.0,
                            breathe: true,
                            scale: 0.85
                        )
                        .frame(width: 170)
                    }
                    .opacity(silhouetteIn ? 1 : 0)
                    .offset(y: silhouetteIn ? 0 : 20)

                    VStack(spacing: 18) {
                        StatBar(label: "STRENGTH", tier: "C", value: 0.62, animate: true, muted: false, startDelay: 0.55)
                            .onAppear { schedHaptic(0, delay: 0.6) }
                        StatBar(label: "STAMINA", tier: "C", value: 0.58, animate: true, muted: false, startDelay: 0.70)
                            .onAppear { schedHaptic(1, delay: 0.75) }
                        StatBar(label: "DISCIPLINE", tier: "B", value: 0.72, animate: true, muted: false, startDelay: 0.85)
                            .onAppear { schedHaptic(2, delay: 0.90) }
                        StatBar(label: "CONFIDENCE", tier: "A", value: 0.82, animate: true, muted: false, startDelay: 1.00)
                            .onAppear { schedHaptic(3, delay: 1.05) }
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

                    Text("Every rep ranked. Every week measured.")
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                silhouetteIn = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
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
