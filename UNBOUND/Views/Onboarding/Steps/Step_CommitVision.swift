import SwiftUI

enum CommitVisionSlide: String, CaseIterable {
    case day30, day90, today

    var chip: String {
        switch self {
        case .day30: return "FIRST ARC"
        case .day90: return "THE CLIMB"
        case .today: return "GATE ONE"
        }
    }

    var icon: String {
        switch self {
        case .day30: return "calendar"
        case .day90: return "star.square.fill"
        case .today: return "flame.fill"
        }
    }

    var assetName: String {
        switch self {
        case .day30: return "onboarding_path_day30_card"
        case .day90: return "onboarding_path_rank_gates"
        case .today: return "onboarding_path_open_gate"
        }
    }

    var hudStep: OnboardingStep {
        switch self {
        case .day30: return .commitDay30
        case .day90: return .commitDay90
        case .today: return .commitToday
        }
    }
}

struct Step_CommitVision: View {
    @Bindable var flow: OnboardingFlowViewModel
    let slide: CommitVisionSlide
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var hasAnimated = false
    @State private var staircaseStoryVisible = false
    @State private var staircaseButtonVisible = false

    @ViewBuilder
    var body: some View {
        if slide == .day90 {
            staircaseReveal
        } else {
            OnboardingScaffold(
                title: nil,
                subtitle: nil,
                progress: progress,
                primaryTitle: slide == .today ? "I'm ready" : "Keep going",
                primaryIcon: "arrow.right",
                hudStep: slide.hudStep,
                onBack: onBack,
                onPrimary: onContinue
            ) {
                VStack(spacing: 0) {
                    visionHero

                    HStack(spacing: 8) {
                        Image(systemName: slide.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(slide.chip)
                            .font(Font.unbound.monoS)
                            .tracking(1.8)
                    }
                    .foregroundStyle(Color.unbound.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .overlay(
                        ChamferedRectangle(inset: 4)
                            .stroke(Color.unbound.accent.opacity(0.55), lineWidth: 1)
                    )

                    Spacer().frame(height: 28)

                    Text(headlineText)
                        .font(Font.unbound.displayM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.unbound.accent.opacity(0.3), radius: 14)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 20)

                    Text(bodyCopy)
                        .font(Font.unbound.bodyL)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 20)

                    HStack(spacing: 6) {
                        ForEach(CommitVisionSlide.allCases, id: \.self) { s in
                            ChamferedRectangle(inset: 1)
                                .fill(s == slide ? Color.unbound.accent : Color.unbound.border)
                                .frame(width: s == slide ? 22 : 6, height: 6)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: slide)
                }
                .frame(maxWidth: .infinity)
                .opacity(hasAnimated ? 1 : 0)
                .offset(y: hasAnimated ? 0 : 14)
                .onAppear {
                    withAnimation(.spring(response: 0.65, dampingFraction: 0.88)) {
                        hasAnimated = true
                    }
                    if slide == .today {
                        UnboundHaptics.heavy()
                    }
                }
            }
        }
    }

    private var staircaseReveal: some View {
        GeometryReader { proxy in
            ZStack {
                Image("onboarding_path_rank_gates")
                    .resizable()
                    .scaledToFill()
                    .frame(width: fullBleedSize(proxy).width, height: fullBleedSize(proxy).height)
                    .scaleEffect(hasAnimated ? 1.02 : 3.28, anchor: .bottom)
                    .offset(y: 0)
                    .saturation(hasAnimated ? 1.18 : 0.76)
                    .brightness(hasAnimated ? 0.02 : -0.22)
                    .contrast(hasAnimated ? 1.08 : 1.18)
                    .clipped()
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 3.35), value: hasAnimated)

                staircaseRevealGlow
                staircaseVignette

                VStack(spacing: 16) {
                    Spacer(minLength: 0)

                    staircaseStoryPanel
                        .opacity(staircaseStoryVisible ? 1 : 0)
                        .offset(y: staircaseStoryVisible ? 0 : 22)
                        .animation(.spring(response: 0.58, dampingFraction: 0.84), value: staircaseStoryVisible)

                    HUDButton(
                        title: L10n.onboarding("commitVision.staircase.primary", defaultValue: "Unlock my arc"),
                        icon: "lock.open.fill",
                        action: onContinue
                    )
                    .opacity(staircaseButtonVisible ? 1 : 0)
                    .scaleEffect(staircaseButtonVisible ? 1 : 0.94)
                    .animation(.spring(response: 0.55, dampingFraction: 0.82), value: staircaseButtonVisible)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 8))
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            hasAnimated = false
            staircaseStoryVisible = false
            staircaseButtonVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                hasAnimated = true
                UnboundHaptics.heavy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
                staircaseStoryVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
                staircaseButtonVisible = true
            }
        }
    }

    private var staircaseStoryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.onboarding("commitVision.staircase.eyebrow", defaultValue: "THE WHOLE LADDER"))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(Color.unbound.accent)

            Text(L10n.onboarding("commitVision.staircase.title", defaultValue: "You are standing at the bottom."))
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.onboarding("commitVision.staircase.body", defaultValue: "The first step is small on purpose. Log the work, clear the sessions, and the staircase starts revealing the version above you."))
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.76),
                    Color.black.opacity(0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var staircaseRevealGlow: some View {
        VStack {
            Spacer()
            RadialGradient(
                colors: [
                    Color.unbound.accent.opacity(hasAnimated ? 0.34 : 0.08),
                    Color.unbound.impact.opacity(hasAnimated ? 0.14 : 0.02),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 20,
                endRadius: hasAnimated ? 420 : 80
            )
            .frame(height: 360)
            .blur(radius: hasAnimated ? 8 : 20)
            .animation(.easeOut(duration: 2.2), value: hasAnimated)
        }
        .ignoresSafeArea()
    }

    private var staircaseVignette: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0.84), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 230)

            Spacer()

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.12), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 350)
        }
        .ignoresSafeArea()
    }

    private func fullBleedSize(_ proxy: GeometryProxy) -> CGSize {
        CGSize(
            width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
            height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        )
    }


    @ViewBuilder
    private var visionHero: some View {
        Image(slide.assetName)
            .resizable()
            .scaledToFill()
            .frame(height: slide == .today ? 292 : 318)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.08), Color.clear, Color.black.opacity(0.46)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.32), lineWidth: 1)
            )
            .shadow(color: Color.unbound.accent.opacity(0.22), radius: 18)
            .padding(.bottom, 22)
    }

    private var archetypeName: String {
        // TODO(Phase 17): wire to BuildIdentity once archetype is fully removed
        "UNBOUND"
    }

    private var firstNodeTitle: String {
        // TODO(Phase 17): derive from seededAttributes BuildIdentity
        let tree = SkillTree.universal
        return tree.nodes.first?.title ?? "Your first unlock"
    }

    private var midNodeTitle: String {
        // TODO(Phase 17): derive from seededAttributes BuildIdentity
        let tree = SkillTree.universal
        let mid = tree.nodes.first(where: { $0.position.row == 3 })
        return mid?.title ?? tree.nodes[safe: 3]?.title ?? "A node nobody else sees"
    }

    private var sessionsPerWeek: Int {
        switch flow.targetFrequency {
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case nil: return 4
        }
    }

    private var headlineText: String {
        switch slide {
        case .day30:
            return "Your first arc is loaded."
        case .day90:
            return "The higher gates stop looking impossible."
        case .today:
            return "Open the gate."
        }
    }

    private var bodyCopy: String {
        switch slide {
        case .day30:
            return "For the next four weeks, UNBOUND gives you the route: \(sessionsPerWeek)x/week training, recovery targets, check-ins, and visible proof that you are not stuck at Day Zero."
        case .day90:
            return "The ladder is not decoration. Your logged sessions, skill progress, and rank movement keep turning into the next visible step."
        case .today:
            return "Your first route is loaded. Step through and start becoming the version that actually keeps showing up."
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
