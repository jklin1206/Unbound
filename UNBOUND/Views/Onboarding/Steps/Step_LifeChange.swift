import SwiftUI

enum LifeChangeSlide: String, CaseIterable {
    case energy, strength, confidence, sleep, looksFeel

    var icon: String {
        switch self {
        case .energy:     return "bolt.fill"
        case .strength:   return "heart.fill"
        case .confidence: return "brain.head.profile"
        case .sleep:      return "moon.stars.fill"
        case .looksFeel:  return "figure.mind.and.body"
        }
    }

    var headline: String {
        switch self {
        case .energy:     return "Stop running out of gas at 3 pm."
        case .strength:   return "A body that doesn't fight you."
        case .confidence: return "Your mood isn't random."
        case .sleep:      return "Fall asleep in ten minutes, not two hours."
        case .looksFeel:  return "Feel at home in your body."
        }
    }

    var body: String {
        switch self {
        case .energy:
            return "Training shifts your baseline. Within a few weeks you stop dragging through afternoons — your body just has more to give."
        case .strength:
            return "The creaks, the twinges, the \"I must have slept wrong\" — those fade. You stop negotiating with your body. It becomes something you trust, not something you manage."
        case .confidence:
            return "Training is the most reliable thing we have for how you feel day-to-day. Calmer head, sharper focus, fewer bad days. This is the part of health nobody sells you on, but it's the part you feel first."
        case .sleep:
            return "Consistent training regulates everything — cortisol, core temperature, recovery. You wake up actually rested."
        case .looksFeel:
            return "You'll move better. Breathe deeper. Stand taller without thinking about it. The mirror stops being something you brace for and starts being a place you recognize yourself."
        }
    }

    var hudStep: OnboardingStep {
        switch self {
        case .energy: return .lifeChangeEnergy
        case .strength: return .lifeChangeStrength
        case .confidence: return .lifeChangeConfidence
        case .sleep: return .lifeChangeSleep
        case .looksFeel: return .lifeChangeLooksFeel
        }
    }
}

struct Step_LifeChange: View {
    let slide: LifeChangeSlide
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var hasAnimated = false

    var body: some View {
        OnboardingScaffold(
            title: nil,
            subtitle: nil,
            progress: progress,
            primaryTitle: "Keep going",
            primaryIcon: "arrow.right",
            hudStep: slide.hudStep,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.unbound.accent.opacity(0.32), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 130
                            )
                        )
                        .frame(width: 240, height: 240)

                    HUDHexagon()
                        .stroke(Color.unbound.accent.opacity(0.45), lineWidth: 1.5)
                        .frame(width: 170, height: 156)
                        .animeGlow(color: Color.unbound.accent, radius: 18, intensity: 0.85)

                    Image(systemName: slide.icon)
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Color.unbound.accent)
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 14)
                }

                Spacer().frame(height: 32)

                VStack(spacing: 18) {
                    Text(slide.headline)
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.unbound.accent.opacity(0.22), radius: 12)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(slide.body)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 12)
                .opacity(hasAnimated ? 1 : 0)
                .offset(y: hasAnimated ? 0 : 12)

                Spacer().frame(height: 24)

                HStack(spacing: 6) {
                    ForEach(LifeChangeSlide.allCases, id: \.self) { s in
                        ChamferedRectangle(inset: 1)
                            .fill(s == slide ? Color.unbound.accent : Color.unbound.border)
                            .frame(width: s == slide ? 22 : 6, height: 6)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: slide)
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.88)) {
                    hasAnimated = true
                }
            }
        }
    }
}
