import SwiftUI

// MARK: - OnboardingScaffold
//
// Shared chrome for every onboarding screen (except Splash which opts out
// via the `showsBackButton: false` and `showsProgress: false` flags).
//
// Two modes:
//   - Default (hudStep == nil): original capsule progress + UnboundButton CTA
//   - HUD (hudStep != nil): anime-HUD aesthetic — AnimeBackdrop(.smoky) +
//     TechGridBackground + embers + HUDProgressBar + HUDButton. Used by the
//     restyled answer steps (Gender, Experience, CurrentFrequency,
//     TargetFrequency, SessionLength). Data binding is untouched.

struct OnboardingScaffold<Content: View>: View {
    let title: String?
    let subtitle: String?
    var progress: Double = 0
    var showsBackButton: Bool = true
    var showsProgress: Bool = true
    var primaryTitle: String = "Continue"
    var primaryIcon: String? = nil
    var primaryEnabled: Bool = true
    var hudStep: OnboardingStep? = nil
    var onBack: (() -> Void)? = nil
    var onPrimary: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        if hudStep != nil {
            hudBody
        } else {
            defaultBody
        }
    }

    // MARK: Default (legacy) layout

    private var defaultBody: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                legacyTopBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let title {
                            Text(title)
                                .font(Font.unbound.titleL)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if title != nil || subtitle != nil {
                            Spacer().frame(height: 12)
                        }
                        content()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                UnboundButton(
                    title: primaryTitle,
                    variant: .primary,
                    icon: primaryIcon,
                    isEnabled: primaryEnabled,
                    action: onPrimary
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var legacyTopBar: some View {
        HStack(spacing: 16) {
            if showsBackButton {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            if showsProgress {
                OnboardingProgressBar(progress: progress)
            } else {
                Spacer()
            }

            Color.clear.frame(width: 36, height: 36)
        }
    }

    // MARK: HUD layout

    private var hudBody: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .smoky, intensity: 0.9)
                .ignoresSafeArea()
            TechGridBackground(opacity: 0.28)
                .ignoresSafeArea()
            ParticleEmitter(config: .embers)
                .opacity(0.3)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                hudTopBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let title {
                            Text(title.uppercased())
                                .font(Font.unbound.titleL)
                                .tracking(0.8)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .shadow(color: Color.unbound.accent.opacity(0.28), radius: 14)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if title != nil || subtitle != nil {
                            Spacer().frame(height: 12)
                        }
                        content()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HUDButton(
                    title: primaryTitle,
                    icon: primaryIcon ?? "arrow.right",
                    isEnabled: primaryEnabled,
                    action: onPrimary
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var hudTopBar: some View {
        if let step = hudStep {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    if showsBackButton {
                        Button(action: { onBack?() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.unbound.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    ChamferedRectangle(inset: 4)
                                        .stroke(Color.unbound.borderSubtle, lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }

                HUDProgressBar(
                    currentStep: step.rawValue + 1,
                    totalSteps: OnboardingStep.total,
                    category: step.category
                )
            }
        }
    }
}

#Preview("Legacy") {
    OnboardingScaffold(
        title: "What's your activity level?",
        subtitle: "We'll calibrate your starting protocol intensity.",
        progress: 0.35,
        onPrimary: {}
    ) {
        VStack(spacing: 12) {
            ForEach(["Sedentary", "Lightly active", "Moderately active", "Very active"], id: \.self) { label in
                UnboundCard {
                    HStack {
                        Text(label)
                            .font(Font.unbound.bodyLStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Spacer()
                    }
                }
            }
        }
    }
}

#Preview("HUD") {
    OnboardingScaffold(
        title: "How often do you train now?",
        subtitle: nil,
        primaryEnabled: true,
        hudStep: .targetFrequency,
        onBack: {},
        onPrimary: {}
    ) {
        VStack(spacing: 12) {
            HUDSelectRow(index: 1, title: "0 days", subtitle: "Starting fresh", isSelected: false, onTap: {})
            HUDSelectRow(index: 2, title: "1–2 days", subtitle: "Occasional", isSelected: false, onTap: {})
            HUDSelectRow(index: 3, title: "3–4 days", subtitle: "Consistent", isSelected: false, onTap: {})
            HUDSelectRow(index: 4, title: "5+ days", subtitle: "Heavy volume", isSelected: true, onTap: {})
        }
    }
}
