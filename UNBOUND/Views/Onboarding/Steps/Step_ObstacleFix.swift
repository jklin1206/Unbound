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
            primaryTitle: "Show me my path",
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
                            Text("YOU SAID")
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
                    eyebrow: "SYSTEM LOCK",
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
        let sessionLength = flow.sessionLength?.displayName ?? "45 minutes"
        let firstUnlock = SkillTree.universal.nodes.first?.title ?? "your first node"
        let focus = flow.targetAreas.first?.displayName.lowercased() ?? "your main focus area"

        switch obstacle {
        case .unsure:
            return ObstacleFixPlan(
                title: "No more guessing.",
                subtitle: "You said you don't know what to do. UNBOUND gives the next move a shape.",
                fixes: [
                    .init(icon: "map.fill", title: "Your next move is visible", detail: "Every session points toward \(firstUnlock), not a random workout."),
                    .init(icon: "list.bullet.clipboard.fill", title: "The week is already built", detail: "\(sessions) sessions per week, \(sessionLength) each, matched to your equipment and focus."),
                    .init(icon: "arrow.triangle.2.circlepath", title: "The path keeps moving", detail: "Finish the work, and the next target steps into view.")
                ],
                callout: "The first fix is clarity: open the app, see the target, do the next session."
            )
        case .consistency:
            return ObstacleFixPlan(
                title: "Showing up starts to matter.",
                subtitle: "You said consistency breaks. So every return needs to feel like progress.",
                fixes: [
                    .init(icon: "calendar.badge.clock", title: "Your days are locked", detail: "Your training days become the rhythm of the arc."),
                    .init(icon: "hexagon.fill", title: "Every session leaves a mark", detail: "The card changes because you showed up."),
                    .init(icon: "flame.fill", title: "Small wins stack", detail: "Streaks and node progress make missed days feel recoverable, not like a full restart.")
                ],
                callout: "The goal is not more willpower. It is a journey you want to return to."
            )
        case .plateau:
            return ObstacleFixPlan(
                title: "The wall can break.",
                subtitle: "You said progress stalled. That means the next push needs to feel different.",
                fixes: [
                    .init(icon: "gauge.with.dots.needle.bottom.50percent", title: "Effort has a target", detail: "Too easy, too hard, or just right stops being a guess."),
                    .init(icon: "chart.line.uptrend.xyaxis", title: "Progress becomes visible", detail: "You can watch \(focus) move instead of hoping it is working."),
                    .init(icon: "arrow.up.right.circle.fill", title: "Targets climb", detail: "When you prove you can handle it, the next wall gets taller.")
                ],
                callout: "A plateau stops feeling permanent when the next wall is named."
            )
        case .time:
            return ObstacleFixPlan(
                title: "The arc fits your life.",
                subtitle: "You said time gets in the way. So the first step has to fit the day you actually have.",
                fixes: [
                    .init(icon: "timer", title: "Session length is capped", detail: "Your workouts are built around \(sessionLength), not an imaginary perfect day."),
                    .init(icon: "scope", title: "Priority comes first", detail: "The plan puts \(focus) work where it matters most, then trims the noise."),
                    .init(icon: "calendar", title: "Frequency stays realistic", detail: "\(sessions) days per week is the pace. No fantasy schedule required.")
                ],
                callout: "The fix is not a bigger plan. It is a sharper one."
            )
        case .motivation:
            return ObstacleFixPlan(
                title: "Motivation becomes momentum.",
                subtitle: "You said motivation fades. The answer is seeing the character move forward.",
                fixes: [
                    .init(icon: "target", title: "A concrete first unlock", detail: "\(firstUnlock) becomes the first visible milestone, not a vague transformation."),
                    .init(icon: "star.fill", title: "The work pays out", detail: "Each session gives you something to watch, keep, and chase."),
                    .init(icon: "person.crop.square", title: "Your card becomes the mirror", detail: "The Day Zero profile keeps the gap visible: where you started, where you are, and what changes next.")
                ],
                callout: "Motivation starts the arc. Visible progress keeps it alive."
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
