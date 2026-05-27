import SwiftUI

enum LifeChangeSlide: String, CaseIterable {
    case energy, strength, confidence, sleep, looksFeel

    static let activeSlides: [LifeChangeSlide] = [.energy, .sleep, .confidence]

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
        case .energy:     return "Wake up with more in the tank."
        case .strength:   return "Strength you can feel outside the gym."
        case .confidence: return "Confidence stops being a mood."
        case .sleep:      return "Recover like the work matters."
        case .looksFeel:  return "Start recognizing yourself again."
        }
    }

    var body: String {
        switch self {
        case .energy:
            return "The first arc is built so showing up gives something back: better days, not just sore workouts."
        case .strength:
            return "You move differently when your body feels capable: stairs, bags, posture, sports, everything."
        case .confidence:
            return "Every session becomes proof you can see. That proof is what makes the next one easier to start."
        case .sleep:
            return "Training, check-ins, and recovery targets stop living in separate places. The system keeps them tied together."
        case .looksFeel:
            return "This is not just a workout plan. It is the first step into a version of you that feels built, not guessed."
        }
    }

    var assetName: String {
        switch self {
        case .energy: return "onboarding_path_open_gate"
        case .sleep: return "onboarding_path_protocol_dossier"
        case .confidence: return "onboarding_path_day30_card"
        case .strength, .looksFeel: return "onboarding_path_transformation"
        }
    }

    var chipTitle: String {
        switch self {
        case .energy: return "ENERGY"
        case .sleep: return "RECOVERY"
        case .confidence: return "PROOF"
        case .strength: return "STRENGTH"
        case .looksFeel: return "BODY"
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
                lifeChangeHero

                Spacer().frame(height: 24)

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
                    ForEach(LifeChangeSlide.activeSlides, id: \.self) { s in
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

    private var lifeChangeHero: some View {
        ZStack(alignment: .bottomLeading) {
            Image(slide.assetName)
                .resizable()
                .scaledToFill()
                .frame(height: 318)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.66)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )

            HStack(spacing: 8) {
                Image(systemName: slide.icon)
                    .font(.system(size: 12, weight: .black))
                Text(slide.chipTitle)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.3)
            }
            .foregroundStyle(Color.unbound.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.58)))
            .overlay(Capsule().strokeBorder(Color.unbound.accent.opacity(0.42), lineWidth: 1))
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(0.2), radius: 18)
    }
}
