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
