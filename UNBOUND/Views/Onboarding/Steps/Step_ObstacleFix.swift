import SwiftUI

// MARK: - Step_ObstacleFix
//
// The confession payoff, placed between social proof and the staircase: the
// quiz asked "what's been in the way?" and this screen answers it in the
// SYSTEM's voice. Calm and centered - no bursts, no card grid: the user's
// own obstacle quoted back, the system's one-line counter, then three short
// personalized lines. If they also confessed "other fitness apps" in prior
// attempts, a kicker names why this one is different.
//
// Full-bleed cinematic: no progress bar, no back (see OnboardingStep lists).

struct Step_ObstacleFix: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var showsConfession = false
    @State private var showsCounter = false
    @State private var visibleFixes = 0
    @State private var showsFooter = false

    private var primaryObstacle: Obstacle {
        let priority: [Obstacle] = [.unsure, .consistency, .plateau, .time, .motivation]
        return priority.first(where: { flow.obstacles.contains($0) }) ?? .unsure
    }

    private var plan: ObstacleFixPlan {
        ObstacleFixPlan.make(for: primaryObstacle, flow: flow)
    }

    private var triedOtherApps: Bool {
        flow.priorAttempts.contains(.otherApps)
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            TechGridBackground(opacity: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                VStack(spacing: 26) {
                    // The confession, in their words.
                    VStack(spacing: 12) {
                        Text(L10n.onboarding("painCost.eyebrow", defaultValue: "[ SYSTEM ]"))
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(Color.unbound.coachCyan)

                        Text(L10n.onboarding("obstacleFix.youSaid", defaultValue: "YOU SAID"))
                            .font(Font.unbound.monoS)
                            .tracking(1.8)
                            .foregroundStyle(Color.unbound.textTertiary)

                        Text("\u{201C}\(primaryObstacle.displayName)\u{201D}")
                            .font(Font.unbound.displayM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.8)
                    }
                    .opacity(showsConfession ? 1 : 0)
                    .offset(y: showsConfession ? 0 : 10)

                    // The counter.
                    Text(plan.counter)
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.accent)
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 16)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showsCounter ? 1 : 0)
                        .scaleEffect(showsCounter ? 1 : 1.08)
                        .blur(radius: showsCounter ? 0 : 5)

                    // Three short lines, personalized from the quiz answers.
                    VStack(spacing: 13) {
                        ForEach(Array(plan.lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(Font.unbound.bodyL)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(visibleFixes > index ? 1 : 0)
                                .offset(y: visibleFixes > index ? 0 : 8)
                        }
                    }
                    .padding(.top, 4)

                    if triedOtherApps {
                        Text(L10n.onboarding("obstacleFix.otherApps.kicker", defaultValue: "Other apps counted streaks. This one counts proof."))
                            .font(Font.unbound.bodyM.weight(.semibold))
                            .foregroundStyle(Color.unbound.ember)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(showsFooter ? 1 : 0)
                    }
                }
                .padding(.horizontal, 30)

                Spacer(minLength: 40)

                UnboundButton(
                    title: L10n.onboarding("obstacleFix.primary", defaultValue: "Show me my path"),
                    icon: "arrow.right",
                    action: onContinue
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .opacity(showsFooter ? 1 : 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: runSequence)
    }

    private func runSequence() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.2)) {
            showsConfession = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UnboundHaptics.medium()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showsCounter = true
            }
            UnboundHaptics.heavy()
        }
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8 + Double(index) * 0.16) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
                    visibleFixes = index + 1
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                showsFooter = true
            }
        }
    }
}

// MARK: - Fix plans (per obstacle, personalized from flow answers)

private struct ObstacleFixPlan {
    let counter: String
    let lines: [String]

    @MainActor
    static func make(for obstacle: Obstacle, flow: OnboardingFlowViewModel) -> ObstacleFixPlan {
        let sessions = flow.targetFrequency?.numericCount ?? 4
        let sessionLength = flow.sessionLength?.displayName ?? L10n.onboarding("common.fortyFiveMinutes", defaultValue: "45 minutes")
        let firstUnlock = SkillTree.universal.nodes.first?.title ?? L10n.onboarding("obstacleFix.firstUnlockFallback", defaultValue: "your first node")
        let focus = flow.targetAreas.first?.displayName.lowercased() ?? L10n.onboarding("obstacleFix.focusFallback", defaultValue: "your main focus area")

        switch obstacle {
        case .unsure:
            return ObstacleFixPlan(
                counter: L10n.onboarding("obstacleFix.unsure.counter", defaultValue: "The next move is always named."),
                lines: [
                    L10n.onboarding("obstacleFix.unsure.line1", defaultValue: "The next move is always on screen."),
                    L10n.onboardingFormat("obstacleFix.unsure.line2", defaultValue: "%d sessions a week, already built for you.", sessions),
                    L10n.onboardingFormat("obstacleFix.unsure.line3", defaultValue: "Finish one, and %@ steps into view.", firstUnlock)
                ]
            )
        case .consistency:
            return ObstacleFixPlan(
                counter: L10n.onboarding("obstacleFix.consistency.counter", defaultValue: "Streaks reset. Gates don't."),
                lines: [
                    L10n.onboarding("obstacleFix.consistency.line1", defaultValue: "A missed week never resets your rank."),
                    L10n.onboardingFormat("obstacleFix.consistency.line2", defaultValue: "%d sessions a week, small on purpose.", sessions),
                    L10n.onboarding("obstacleFix.consistency.line3", defaultValue: "Something visible moves every session.")
                ]
            )
        case .plateau:
            return ObstacleFixPlan(
                counter: L10n.onboarding("obstacleFix.plateau.counter", defaultValue: "Walls here are built to break."),
                lines: [
                    L10n.onboarding("obstacleFix.plateau.line1", defaultValue: "Every set gets a target, not a guess."),
                    L10n.onboardingFormat("obstacleFix.plateau.line2", defaultValue: "You watch %@ move week over week.", focus),
                    L10n.onboarding("obstacleFix.plateau.line3", defaultValue: "Prove it, and the next wall gets named.")
                ]
            )
        case .time:
            return ObstacleFixPlan(
                counter: L10n.onboarding("obstacleFix.time.counter", defaultValue: "The arc fits the day you have."),
                lines: [
                    L10n.onboardingFormat("obstacleFix.time.line1", defaultValue: "Sessions are capped at %@.", sessionLength),
                    L10n.onboardingFormat("obstacleFix.time.line2", defaultValue: "%d days a week. No fantasy schedule.", sessions),
                    L10n.onboardingFormat("obstacleFix.time.line3", defaultValue: "Priority %@ work first, noise trimmed.", focus)
                ]
            )
        case .motivation:
            return ObstacleFixPlan(
                counter: L10n.onboarding("obstacleFix.motivation.counter", defaultValue: "Stakes replace willpower."),
                lines: [
                    L10n.onboardingFormat("obstacleFix.motivation.line1", defaultValue: "%@ is your first visible milestone.", firstUnlock),
                    L10n.onboarding("obstacleFix.motivation.line2", defaultValue: "Every session pays out XP and rank."),
                    L10n.onboarding("obstacleFix.motivation.line3", defaultValue: "Your card keeps the gap visible.")
                ]
            )
        }
    }
}

#if DEBUG
#Preview {
    let flow: OnboardingFlowViewModel = {
        let flow = OnboardingFlowViewModel()
        flow.obstacles = [.consistency]
        flow.priorAttempts = [.otherApps]
        flow.targetFrequency = .four
        flow.sessionLength = .fortyFive
        flow.targetAreas = [.chest]
        return flow
    }()
    Step_ObstacleFix(flow: flow, progress: 0.72, onBack: {}, onContinue: {})
}

#endif
