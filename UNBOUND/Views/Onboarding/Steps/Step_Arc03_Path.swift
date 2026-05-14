import SwiftUI

struct Step_Arc03_Path: View {
    let onBegin: () -> Void

    @State private var silhouetteIn: Bool = false
    @State private var statsIn: Bool = false
    @State private var copyIn: Bool = false
    @State private var archetypeIndex: Int = 0
    @State private var buttonPulse: Bool = false
    @State private var haptTicked: [Bool] = [false, false, false, false]

    private let archetypeCases = Archetype.allCases

    /// Hold time per archetype before cross-fading to the next. Slower than
    /// a literal second so the user has time to read the rank differences
    /// between builds, not just see a blur.
    private let rotationInterval: TimeInterval = 2.6

    /// Stat axes stay constant across every archetype (pattern recognition).
    /// Only the rank values change per build — that's where the identity lives.
    /// Axes match the locked 4-stat canon: Strength / Stamina / Technique / Vitality.
    private let statLabels = ["STRENGTH", "STAMINA", "TECHNIQUE", "VITALITY"]

    /// Per-archetype rank profile. Each tuple aligns to `statLabels` by index.
    /// One S-tier signature per archetype — except SHREDDED, who's the
    /// balanced generalist (all A, no peak, no weakness).
    ///   V-TAPER      → Technique S (precision mastery)
    ///   HEAVYWEIGHT  → Strength S  (immovable mass)
    ///   SLEEPER      → Vitality S  (unbreakable ceiling)
    ///   SHREDDED     → all A       (the athlete's archetype)
    private static func ranks(for archetype: Archetype) -> [(tier: String, value: Double)] {
        switch archetype {
        case .vTaper:    // V-TAPER — precision, posture, quiet dominance
            return [("B", 0.70), ("A", 0.80), ("S", 0.92), ("B", 0.72)]
        case .leanCut:   // SHREDDED — balanced athletic generalist
            return [("B", 0.75), ("A", 0.85), ("A", 0.80), ("A", 0.80)]
        case .heavyDuty: // HEAVYWEIGHT — immovable mass
            return [("S", 0.95), ("C", 0.58), ("B", 0.70), ("A", 0.82)]
        case .shredded:  // SLEEPER — hidden ceiling, unkillable
            return [("A", 0.82), ("A", 0.85), ("C", 0.60), ("S", 0.92)]
        }
    }

    private var currentArchetype: Archetype {
        archetypeCases[archetypeIndex]
    }

    private var currentRanks: [(tier: String, value: Double)] {
        Self.ranks(for: currentArchetype)
    }

    var body: some View {
        ZStack {
            AnimeBackdrop(variant: .godRay, intensity: 1.0)
                .ignoresSafeArea()

            ParticleEmitter(config: .embers, isActive: true)
                .opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                    Text("ARCHETYPE PREVIEW")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(Color.unbound.surface.opacity(0.84))
                )
                .overlay(
                    Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
                .opacity(copyIn ? 1 : 0)
                .offset(y: copyIn ? 0 : -8)
                .padding(.bottom, 12)

                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        Text(currentArchetype.shortName)
                            .font(Font.unbound.captionS)
                            .tracking(1.6)
                            .foregroundStyle(Color.unbound.textTertiary.opacity(0.55))
                            .textCase(.uppercase)
                            .offset(y: -200)
                            .id("label-\(archetypeIndex)")
                            .transition(.opacity)

                        Group {
                            if let uiImage = UIImage(named: currentArchetype.silhouetteAssetName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .shadow(color: Color.unbound.impact.opacity(0.4), radius: 24)
                            } else {
                                SilhouetteView(
                                    rimLight: .impact,
                                    chromaticAberration: 0.0,
                                    breathe: true,
                                    scale: 0.85
                                )
                            }
                        }
                        .id("body-\(archetypeIndex)")
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .frame(width: 190, height: 380)
                    }
                    .animation(.easeInOut(duration: 0.55), value: archetypeIndex)
                    .opacity(silhouetteIn ? 1 : 0)
                    .offset(y: silhouetteIn ? 0 : 20)

                    VStack(spacing: 18) {
                        ForEach(Array(statLabels.enumerated()), id: \.offset) { index, label in
                            let rank = currentRanks[index]
                            StatBar(
                                label: label,
                                tier: rank.tier,
                                value: rank.value,
                                animate: true,
                                muted: false,
                                startDelay: 0.55 + Double(index) * 0.15
                            )
                            .id("stat-\(archetypeIndex)-\(index)")
                            .onAppear { schedHaptic(index, delay: 0.6 + Double(index) * 0.15) }
                        }
                    }
                    .animation(.easeInOut(duration: 0.45), value: archetypeIndex)
                    .frame(maxWidth: .infinity)
                    .opacity(statsIn ? 1 : 0)
                    .offset(y: statsIn ? 0 : 16)
                }
                .padding(.horizontal, 20)

                HStack(spacing: 6) {
                    ForEach(archetypeCases.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == archetypeIndex ? Color.unbound.accent : Color.unbound.borderSubtle)
                            .frame(width: index == archetypeIndex ? 18 : 8, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: archetypeIndex)
                    }
                }
                .padding(.top, 14)
                .opacity(statsIn ? 1 : 0)

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
        .onReceive(Timer.publish(every: rotationInterval, on: .main, in: .common).autoconnect()) { _ in
            archetypeIndex = (archetypeIndex + 1) % archetypeCases.count
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
