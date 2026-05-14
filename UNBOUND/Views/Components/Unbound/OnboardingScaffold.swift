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
            defaultAtmosphere

            VStack(spacing: 0) {
                legacyTopBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerBlock
                        content()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.unbound.bg.opacity(0.92),
                                    Color.unbound.bg
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 18)

                    UnboundButton(
                        title: primaryTitle,
                        variant: .primary,
                        icon: primaryIcon,
                        isEnabled: primaryEnabled,
                        action: onPrimary
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .background(Color.unbound.bg)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var defaultAtmosphere: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [
                    Color.unbound.surface.opacity(0.34),
                    Color.unbound.bg.opacity(0.0),
                    Color.unbound.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Capsule()
                .fill(Color.unbound.ember.opacity(0.18))
                .frame(width: 118, height: 520)
                .rotationEffect(.degrees(28))
                .blur(radius: 48)
                .offset(x: 78, y: -130)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var headerBlock: some View {
        if title != nil || subtitle != nil {
            VStack(alignment: .leading, spacing: 10) {
                if showsProgress {
                    HStack(spacing: 8) {
                        Text("CALIBRATION ARC")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.8)
                            .foregroundStyle(Color.unbound.ember)

                        Text("STEP \(progressStepLabel)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.unbound.surface.opacity(0.9))
                            )
                            .overlay(
                                Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                            )
                    }
                }
                if let title {
                    Text(title)
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(1)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
            .padding(.bottom, 4)
        }
    }

    private var legacyTopBar: some View {
        HStack(spacing: 16) {
            if showsBackButton {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.unbound.surface.opacity(0.72))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            if showsProgress {
                VStack(alignment: .leading, spacing: 7) {
                    OnboardingProgressBar(progress: progress)
                    HStack(spacing: 6) {
                        Text("\(progressPercent)%")
                            .font(Font.unbound.monoS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .monospacedDigit()
                        Text("MAPPED")
                            .font(Font.unbound.captionS.weight(.bold))
                            .tracking(1.3)
                            .foregroundStyle(Color.unbound.textTertiary)

                        Spacer(minLength: 0)

                        Text("\(progressStepLabel)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.unbound.ember)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color.unbound.ember.opacity(0.13))
                            )
                            .overlay(
                                Capsule().strokeBorder(Color.unbound.ember.opacity(0.35), lineWidth: 1)
                            )
                    }
                }
            } else {
                Spacer()
            }

            Color.clear.frame(width: 44, height: 44)
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

    private var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    private var progressStepLabel: String {
        let raw = Int(ceil(progress * Double(OnboardingStep.total)))
        let clamped = max(1, min(OnboardingStep.total, raw))
        return "\(clamped)/\(OnboardingStep.total)"
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
