import SwiftUI

struct Step_Arc03_Path: View {
    let onBegin: () -> Void

    @State private var statsIn: Bool = false
    @State private var copyIn: Bool = false
    @State private var buttonPulse: Bool = false
    @State private var badgeSurge: Bool = false
    @State private var activeRankIndex: Int = -1
    @State private var orbitSpin: Angle = .degrees(0)

    private let ranks = SkillTier.allCases

    var body: some View {
        ZStack {
            AnimeBackdrop(variant: .godRay, intensity: 1.0)
                .ignoresSafeArea()

            ParticleEmitter(config: .embers, isActive: true)
                .opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 64)

                rankOrbit
                    .padding(.horizontal, 22)

                Spacer()

                VStack(spacing: 12) {
                    Text("Climb the ranks")
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .tracking(0.2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text("Every rep moves the ladder.")
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
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true).delay(0.8)) {
                badgeSurge = true
            }
            withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                orbitSpin = .degrees(360)
            }
        }
        .task {
            await runRankLoop()
        }
    }

    // MARK: - Helpers

    @State private var haptTicked: Set<Int> = []

    private var activeRank: SkillTier {
        ranks[max(0, activeRankIndex) % ranks.count]
    }

    private var rankOrbit: some View {
        GeometryReader { geo in
            RankOrbitStage(
                ranks: ranks,
                activeRankIndex: activeRankIndex,
                orbitSpin: orbitSpin,
                statsIn: statsIn,
                copyIn: copyIn,
                badgeSurge: badgeSurge,
                size: geo.size
            )
        }
        .frame(height: 475)
    }

    @MainActor
    private func runRankLoop() async {
        activeRankIndex = -1
        if ProcessInfo.processInfo.arguments.contains("-RankOrbitInitialPreview") {
            return
        }

        try? await Task.sleep(nanoseconds: 2_800_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.82, dampingFraction: 0.76)) {
            activeRankIndex = 0
        }
        UnboundHaptics.soft()

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_850_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.82, dampingFraction: 0.76)) {
                activeRankIndex = (activeRankIndex + 1) % ranks.count
            }
            UnboundHaptics.soft()
        }
    }

    private func schedHaptic(_ index: Int, delay: Double) {
        guard !haptTicked.contains(index) else { return }
        haptTicked.insert(index)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UnboundHaptics.medium()
        }
    }
}

private struct RankOrbitStage: View {
    let ranks: [SkillTier]
    let activeRankIndex: Int
    let orbitSpin: Angle
    let statsIn: Bool
    let copyIn: Bool
    let badgeSurge: Bool
    let size: CGSize

    private var activeRank: SkillTier {
        ranks[max(0, activeRankIndex) % ranks.count]
    }

    private var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private var radius: CGFloat {
        min(size.width, size.height) * 0.43
    }

    var body: some View {
        ZStack {
            ForEach(Array(ranks.enumerated()), id: \.element) { index, tier in
                let selected = activeRankIndex >= 0 && index == activeRankIndex
                let progress = rankProgress(tier)

                RankOrbitBadge(
                    tier: tier,
                    progress: selected ? 1 : progress,
                    selected: selected,
                    badgeSurge: badgeSurge
                )
                .position(selected ? center : orbitPosition(for: index))
                .opacity(statsIn ? badgeOpacity(progress: progress, selected: selected) : 0)
                .scaleEffect(selected ? 1.72 : 1.0)
                .animation(.spring(response: 0.82, dampingFraction: 0.76), value: activeRankIndex)
            }

            rankName
        }
    }

    private var rankName: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 126)

            Text(activeRank.displayName.uppercased())
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: activeRank.rewardTint.opacity(badgeSurge ? 0.85 : 0.42), radius: badgeSurge ? 24 : 10)
                .id(activeRank)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))

            Text(rankSignal(activeRank))
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(activeRank.rewardTextTint)
                .id("signal-\(activeRank.rawValue)")
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .frame(width: size.width, height: size.height)
        .opacity(copyIn && activeRankIndex >= 0 ? 1 : 0)
    }

    private func orbitPosition(for index: Int) -> CGPoint {
        let angle = (Double(index) / Double(ranks.count) * 360) + orbitSpin.degrees - 90
        let radians = CGFloat(angle * .pi / 180)
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    private func rankProgress(_ tier: SkillTier) -> CGFloat {
        CGFloat(tier.rawValue) / CGFloat(max(1, SkillTier.ascendant.rawValue))
    }

    private func badgeOpacity(progress: CGFloat, selected: Bool) -> Double {
        selected ? 1 : 0.78
    }

    private func rankSignal(_ tier: SkillTier) -> String {
        switch tier {
        case .initiate: return "STARTING LINE"
        case .novice: return "FIRST CLEAR"
        case .apprentice: return "FORMING"
        case .forged: return "BUILT UNDER LOAD"
        case .veteran: return "PROVEN"
        case .honed: return "SHARPENED"
        case .vessel: return "HIGH TIER"
        case .unbound: return "RESTRICTION BROKEN"
        case .ascendant: return "APEX"
        }
    }
}

private struct RankOrbitBadge: View {
    let tier: SkillTier
    let progress: CGFloat
    let selected: Bool
    let badgeSurge: Bool

    private var isHighEnergy: Bool {
        selected
    }

    private var isTopEnergy: Bool {
        selected
    }

    var body: some View {
        ZStack {
            if isHighEnergy {
                Circle()
                    .stroke(tier.rewardTint.opacity(badgeSurge ? 0.5 : 0.22), lineWidth: isTopEnergy ? 4 : 2)
                    .frame(width: auraSize, height: auraSize)
                    .blur(radius: isTopEnergy ? 2.5 : 1.5)
                Circle()
                    .fill(tier.rewardTint.opacity(badgeSurge ? 0.22 : 0.08))
                    .frame(width: auraSize - 6, height: auraSize - 6)
            }

            Image(tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: badgeSize, height: badgeSize)
                .shadow(color: badgeShadow, radius: selected ? 24 : (isTopEnergy ? 15 : 8))
        }
        .frame(width: badgeFrame, height: badgeFrame)
        .shadow(color: tier.rewardTint.opacity(selected ? 0.82 : 0.18), radius: selected ? 30 : 10)
        .scaleEffect(selected && badgeSurge ? 1.08 : 1.0)
    }

    private var badgeSize: CGFloat {
        selected ? 56 : 46
    }

    private var auraSize: CGFloat {
        selected ? 86 : 68
    }

    private var badgeFrame: CGFloat {
        selected ? 96 : 74
    }

    private var badgeShadow: Color {
        isHighEnergy ? tier.rewardTint.opacity(badgeSurge ? 0.7 : 0.34) : .clear
    }
}

#Preview {
    Step_Arc03_Path(onBegin: {})
}
