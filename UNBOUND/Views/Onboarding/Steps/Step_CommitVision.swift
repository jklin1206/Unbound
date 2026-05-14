import SwiftUI

enum CommitVisionSlide: String, CaseIterable {
    case day30, day90, today

    var chip: String {
        switch self {
        case .day30: return "30 DAYS IN"
        case .day90: return "90 DAYS IN"
        case .today: return "STARTING TODAY"
        }
    }

    var icon: String {
        switch self {
        case .day30: return "calendar"
        case .day90: return "star.square.fill"
        case .today: return "flame.fill"
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

    var body: some View {
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
                Spacer().frame(height: 24)

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

                Spacer().frame(height: 24)

                if slide != .today {
                    visionPanel
                }

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

    @ViewBuilder
    private var visionPanel: some View {
        HUDPanel(isActive: true, pulse: true) {
            HStack(spacing: 14) {
                Image(systemName: slide == .day30 ? "target" : "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(slide == .day30 ? "YOUR FIRST UNLOCK" : "WHAT YOU'LL HAVE HIT")
                        .font(Font.unbound.monoS)
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.accent)
                    Text(slide == .day30 ? firstNodeTitle : midNodeTitle)
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
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
            return "In 30 days, you'll hit your first unlock."
        case .day90:
            return "In 90 days, \(archetypeName) isn't a goal. It's a label."
        case .today:
            return "All of this starts today."
        }
    }

    private var bodyCopy: String {
        switch slide {
        case .day30:
            return "Training \(sessionsPerWeek) days a week. Showing up on days you don't feel like it. By week four you'll feel different before you look different."
        case .day90:
            return "You'll be halfway through your protocol. Friends will start noticing. Your own mirror will start agreeing. And you'll still be earlier than you think in the real transformation."
        case .today:
            return "You don't become this person by wanting to. You become this person by starting. Today is where the 30-day version of you begins."
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
