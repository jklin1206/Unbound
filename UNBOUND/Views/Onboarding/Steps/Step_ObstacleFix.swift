import SwiftUI

struct Step_ObstacleFix: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var hasAnimated = false

    private var primaryObstacle: Obstacle {
        let priority: [Obstacle] = [.unsure, .consistency, .plateau, .time, .motivation]
        return priority.first(where: { flow.obstacles.contains($0) }) ?? .unsure
    }

    private var plan: ObstacleFixPlan {
        ObstacleFixPlan.make(for: primaryObstacle, flow: flow)
    }

    var body: some View {
        OnboardingScaffold(
            title: plan.title,
            subtitle: plan.subtitle,
            progress: progress,
            primaryTitle: L10n.onboarding("obstacleFix.primary", defaultValue: "Show me my path"),
            primaryIcon: "arrow.right",
            hudStep: .obstacleFix,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 14) {
                UnboundCard {
                    HStack(alignment: .center, spacing: 14) {
                        ZStack {
                            HUDHexagon()
                                .fill(Color.unbound.rankRed.opacity(0.16))
                            HUDHexagon()
                                .stroke(Color.unbound.rankRed.opacity(0.65), lineWidth: 1.4)
                            Image(systemName: primaryObstacle.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.unbound.rankRed)
                        }
                        .frame(width: 54, height: 50)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.onboarding("obstacleFix.youSaid", defaultValue: "YOU SAID"))
                                .font(Font.unbound.captionS)
                                .tracking(1.5)
                                .foregroundStyle(Color.unbound.textTertiary)
                            Text(primaryObstacle.displayName.uppercased())
                                .font(Font.unbound.titleS)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .opacity(hasAnimated ? 1 : 0)
                .offset(y: hasAnimated ? 0 : 12)

                VStack(spacing: 10) {
                    ForEach(Array(plan.fixes.enumerated()), id: \.offset) { index, fix in
                        fixRow(index: index + 1, fix: fix)
                            .opacity(hasAnimated ? 1 : 0)
                            .offset(x: hasAnimated ? 0 : 16)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.84).delay(0.12 + Double(index) * 0.08),
                                value: hasAnimated
                            )
                    }
                }

                HUDCallout(
                    iconSystemName: "checkmark.seal.fill",
                    eyebrow: L10n.onboarding("obstacleFix.systemLock", defaultValue: "SYSTEM LOCK"),
                    message: plan.callout
                )
                .opacity(hasAnimated ? 1 : 0)
                .padding(.top, 2)
            }
            .onAppear {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
                    hasAnimated = true
                }
            }
        }
    }

    private func fixRow(index: Int, fix: ObstacleFix) -> some View {
        HUDPanel(isActive: index == 1, pulse: index == 1) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    HUDHexagon()
                        .fill(index == 1 ? Color.unbound.accent.opacity(0.18) : Color.unbound.surface.opacity(0.9))
                    HUDHexagon()
                        .stroke(index == 1 ? Color.unbound.accent.opacity(0.7) : Color.unbound.borderSubtle, lineWidth: 1.2)
                    Text(String(format: "%02d", index))
                        .font(Font.unbound.monoS)
                        .foregroundStyle(index == 1 ? Color.unbound.accent : Color.unbound.textTertiary)
                }
                .frame(width: 38, height: 34)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: fix.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.unbound.accent)
                        Text(fix.title.uppercased())
                            .font(Font.unbound.bodyMStrong)
                            .tracking(0.6)
                            .foregroundStyle(Color.unbound.textPrimary)
                    }

                    Text(fix.detail)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

private struct ObstacleFixPlan {
    let title: String
    let subtitle: String
    let fixes: [ObstacleFix]
    let callout: String

    @MainActor
    static func make(for obstacle: Obstacle, flow: OnboardingFlowViewModel) -> ObstacleFixPlan {
        let sessions = flow.targetFrequency?.numericCount ?? 4
        let sessionLength = flow.sessionLength?.displayName ?? L10n.onboarding("common.fortyFiveMinutes", defaultValue: "45 minutes")
        let firstUnlock = SkillTree.universal.nodes.first?.title ?? L10n.onboarding("obstacleFix.firstUnlockFallback", defaultValue: "your first node")
        let focus = flow.targetAreas.first?.displayName.lowercased() ?? L10n.onboarding("obstacleFix.focusFallback", defaultValue: "your main focus area")

        switch obstacle {
        case .unsure:
            return ObstacleFixPlan(
                title: L10n.onboarding("obstacleFix.unsure.title", defaultValue: "No more guessing."),
                subtitle: L10n.onboarding("obstacleFix.unsure.subtitle", defaultValue: "You said you don't know what to do. UNBOUND gives the next move a shape."),
                fixes: [
                    .init(
                        icon: "map.fill",
                        title: L10n.onboarding("obstacleFix.unsure.fix1.title", defaultValue: "Your next move is visible"),
                        detail: L10n.onboardingFormat("obstacleFix.unsure.fix1.detail", defaultValue: "Every session points toward %@, not a random workout.", firstUnlock)
                    ),
                    .init(
                        icon: "list.bullet.clipboard.fill",
                        title: L10n.onboarding("obstacleFix.unsure.fix2.title", defaultValue: "The week is already built"),
                        detail: L10n.onboardingFormat("obstacleFix.unsure.fix2.detail", defaultValue: "%d sessions per week, %@ each, matched to your equipment and focus.", sessions, sessionLength)
                    ),
                    .init(
                        icon: "arrow.triangle.2.circlepath",
                        title: L10n.onboarding("obstacleFix.unsure.fix3.title", defaultValue: "The path keeps moving"),
                        detail: L10n.onboarding("obstacleFix.unsure.fix3.detail", defaultValue: "Finish the work, and the next target steps into view.")
                    )
                ],
                callout: L10n.onboarding("obstacleFix.unsure.callout", defaultValue: "The first fix is clarity: open the app, see the target, do the next session.")
            )
        case .consistency:
            return ObstacleFixPlan(
                title: L10n.onboarding("obstacleFix.consistency.title", defaultValue: "Showing up starts to matter."),
                subtitle: L10n.onboarding("obstacleFix.consistency.subtitle", defaultValue: "You said consistency breaks. So every return needs to feel like progress."),
                fixes: [
                    .init(
                        icon: "calendar.badge.clock",
                        title: L10n.onboarding("obstacleFix.consistency.fix1.title", defaultValue: "Your days are locked"),
                        detail: L10n.onboarding("obstacleFix.consistency.fix1.detail", defaultValue: "Your training days become the rhythm of the arc.")
                    ),
                    .init(
                        icon: "hexagon.fill",
                        title: L10n.onboarding("obstacleFix.consistency.fix2.title", defaultValue: "Every session leaves a mark"),
                        detail: L10n.onboarding("obstacleFix.consistency.fix2.detail", defaultValue: "The card changes because you showed up.")
                    ),
                    .init(
                        icon: "flame.fill",
                        title: L10n.onboarding("obstacleFix.consistency.fix3.title", defaultValue: "Small wins stack"),
                        detail: L10n.onboarding("obstacleFix.consistency.fix3.detail", defaultValue: "Streaks and node progress make missed days feel recoverable, not like a full restart.")
                    )
                ],
                callout: L10n.onboarding("obstacleFix.consistency.callout", defaultValue: "The goal is not more willpower. It is a journey you want to return to.")
            )
        case .plateau:
            return ObstacleFixPlan(
                title: L10n.onboarding("obstacleFix.plateau.title", defaultValue: "The wall can break."),
                subtitle: L10n.onboarding("obstacleFix.plateau.subtitle", defaultValue: "You said progress stalled. That means the next push needs to feel different."),
                fixes: [
                    .init(
                        icon: "gauge.with.dots.needle.bottom.50percent",
                        title: L10n.onboarding("obstacleFix.plateau.fix1.title", defaultValue: "Effort has a target"),
                        detail: L10n.onboarding("obstacleFix.plateau.fix1.detail", defaultValue: "Too easy, too hard, or just right stops being a guess.")
                    ),
                    .init(
                        icon: "chart.line.uptrend.xyaxis",
                        title: L10n.onboarding("obstacleFix.plateau.fix2.title", defaultValue: "Progress becomes visible"),
                        detail: L10n.onboardingFormat("obstacleFix.plateau.fix2.detail", defaultValue: "You can watch %@ move instead of hoping it is working.", focus)
                    ),
                    .init(
                        icon: "arrow.up.right.circle.fill",
                        title: L10n.onboarding("obstacleFix.plateau.fix3.title", defaultValue: "Targets climb"),
                        detail: L10n.onboarding("obstacleFix.plateau.fix3.detail", defaultValue: "When you prove you can handle it, the next wall gets taller.")
                    )
                ],
                callout: L10n.onboarding("obstacleFix.plateau.callout", defaultValue: "A plateau stops feeling permanent when the next wall is named.")
            )
        case .time:
            return ObstacleFixPlan(
                title: L10n.onboarding("obstacleFix.time.title", defaultValue: "The arc fits your life."),
                subtitle: L10n.onboarding("obstacleFix.time.subtitle", defaultValue: "You said time gets in the way. So the first step has to fit the day you actually have."),
                fixes: [
                    .init(
                        icon: "timer",
                        title: L10n.onboarding("obstacleFix.time.fix1.title", defaultValue: "Session length is capped"),
                        detail: L10n.onboardingFormat("obstacleFix.time.fix1.detail", defaultValue: "Your workouts are built around %@, not an imaginary perfect day.", sessionLength)
                    ),
                    .init(
                        icon: "scope",
                        title: L10n.onboarding("obstacleFix.time.fix2.title", defaultValue: "Priority comes first"),
                        detail: L10n.onboardingFormat("obstacleFix.time.fix2.detail", defaultValue: "The plan puts %@ work where it matters most, then trims the noise.", focus)
                    ),
                    .init(
                        icon: "calendar",
                        title: L10n.onboarding("obstacleFix.time.fix3.title", defaultValue: "Frequency stays realistic"),
                        detail: L10n.onboardingFormat("obstacleFix.time.fix3.detail", defaultValue: "%d days per week is the pace. No fantasy schedule required.", sessions)
                    )
                ],
                callout: L10n.onboarding("obstacleFix.time.callout", defaultValue: "The fix is not a bigger plan. It is a sharper one.")
            )
        case .motivation:
            return ObstacleFixPlan(
                title: L10n.onboarding("obstacleFix.motivation.title", defaultValue: "Motivation becomes momentum."),
                subtitle: L10n.onboarding("obstacleFix.motivation.subtitle", defaultValue: "You said motivation fades. The answer is seeing the character move forward."),
                fixes: [
                    .init(
                        icon: "target",
                        title: L10n.onboarding("obstacleFix.motivation.fix1.title", defaultValue: "A concrete first unlock"),
                        detail: L10n.onboardingFormat("obstacleFix.motivation.fix1.detail", defaultValue: "%@ becomes the first visible milestone, not a vague transformation.", firstUnlock)
                    ),
                    .init(
                        icon: "star.fill",
                        title: L10n.onboarding("obstacleFix.motivation.fix2.title", defaultValue: "The work pays out"),
                        detail: L10n.onboarding("obstacleFix.motivation.fix2.detail", defaultValue: "Each session gives you something to watch, keep, and chase.")
                    ),
                    .init(
                        icon: "person.crop.square",
                        title: L10n.onboarding("obstacleFix.motivation.fix3.title", defaultValue: "Your card becomes the mirror"),
                        detail: L10n.onboarding("obstacleFix.motivation.fix3.detail", defaultValue: "The Day Zero profile keeps the gap visible: where you started, where you are, and what changes next.")
                    )
                ],
                callout: L10n.onboarding("obstacleFix.motivation.callout", defaultValue: "Motivation starts the arc. Visible progress keeps it alive.")
            )
        }
    }
}

private struct ObstacleFix {
    let icon: String
    let title: String
    let detail: String
}

#Preview {
    let flow = OnboardingFlowViewModel()
    flow.obstacles = [.consistency]
    flow.targetFrequency = .four
    flow.sessionLength = .fortyFive
    flow.targetAreas = [.chest]
    return Step_ObstacleFix(flow: flow, progress: 0.72, onBack: {}, onContinue: {})
}
