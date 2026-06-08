import SwiftUI
import StoreKit

struct Step_ProblemFrame: View {
    let onContinue: () -> Void

    @State private var hasAnimated = false

    private let baselineLevels: [AttributeKey: Int] = [
        .power: 1,
        .vitality: 1,
        .control: 1,
        .endurance: 2,
        .mobility: 2,
        .explosiveness: 1
    ]

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .godRay, intensity: 0.78)
                .ignoresSafeArea()
            ParticleEmitter(config: .embers)
                .opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 44)

                VStack(spacing: 9) {
                    Text(L10n.onboarding("problemOpening.eyebrow", defaultValue: "DAY ZERO"))
                        .font(Font.unbound.monoS)
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.accent)

                    Text(L10n.onboarding("problemOpening.title", defaultValue: "You shouldn't have to guess your way through training."))
                        .font(Font.unbound.displayM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(L10n.onboarding("problemOpening.body", defaultValue: "Random workouts, invisible progress, and missed weeks make it too easy to lose the arc."))
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .opacity(hasAnimated ? 1 : 0)

                Spacer().frame(height: 12)

                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        SilhouetteView(
                            rimLight: .dim,
                            chromaticAberration: 0.38,
                            breathe: true,
                            scale: 0.72,
                            asset: .dormant
                        )
                        .frame(width: 154, height: 334)
                    }
                    .frame(width: 154, height: 334)
                    .opacity(hasAnimated ? 1 : 0)
                    .offset(x: hasAnimated ? 0 : -14)

                    startingProfileCard
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(hasAnimated ? 1 : 0)
                        .offset(x: hasAnimated ? 0 : 14)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 24)

                UnboundButton(title: L10n.onboarding("problemOpening.cta", defaultValue: "Show the ladder"), icon: "arrow.right", action: onContinue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .opacity(hasAnimated ? 1 : 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.86).delay(0.12)) {
                hasAnimated = true
            }
        }
    }

    private var startingProfileCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.onboarding("problemOpening.startingPoint", defaultValue: "STARTING POINT"))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(SkillTier.initiate.displayName.uppercased())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }

                Spacer(minLength: 6)

                Image(SkillTier.initiate.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .shadow(color: Color.unbound.textSecondary.opacity(0.28), radius: 10)
            }

            problemBaselineHex()
                .frame(height: 132)
                .padding(.horizontal, 4)
                .padding(.top, 12)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.onboarding("problemOpening.noRank", defaultValue: "THE PAIN POINTS"))
                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.accent)
                    .lineLimit(1)

                painPointPill(
                    assetName: "exercise_visual_exercise_pushup",
                    tint: Color.unbound.impact,
                    title: L10n.onboarding("problemOpening.pain.guesswork.title", defaultValue: "Guesswork"),
                    detail: L10n.onboarding("problemOpening.pain.guesswork.detail", defaultValue: "You still have to decide what matters today."),
                    imagePadding: 1
                )
                painPointPill(
                    assetName: "badge_art_proof_10",
                    tint: Color.unbound.accent,
                    title: L10n.onboarding("problemOpening.pain.proof.title", defaultValue: "No proof"),
                    detail: L10n.onboarding("problemOpening.pain.proof.detail", defaultValue: "Strength changes, but the progress feels invisible."),
                    imagePadding: 4
                )
                painPointPill(
                    assetName: "badge_art_consistency_loop",
                    tint: Color.unbound.ember,
                    title: L10n.onboarding("problemOpening.pain.restart.title", defaultValue: "Restart loop"),
                    detail: L10n.onboarding("problemOpening.pain.restart.detail", defaultValue: "A busy week can turn into starting over."),
                    imagePadding: 4
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(0.10), radius: 18, y: 10)
    }

    private var baselineHexValues: [AttributeKey: Double] {
        baselineLevels.reduce(into: [:]) { result, entry in
            result[entry.key] = Double(entry.value * 5 + 4)
        }
    }

    private func problemBaselineHex() -> some View {
        GeometryReader { geo in
            let axes: [AttributeKey] = [.power, .vitality, .control, .endurance, .mobility, .explosiveness]
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let chartRadius = side * 0.31
            let labelRadius = side * 0.45

            ZStack {
                AttributeHex(
                    current: baselineHexValues,
                    levels: baselineLevels,
                    tiers: nil,
                    showLabels: false,
                    radius: chartRadius
                )
                .position(center)

                ForEach(Array(axes.enumerated()), id: \.element) { index, key in
                    let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / 6)
                    problemAxisLabel(key)
                        .frame(width: 52)
                        .position(
                            x: center.x + cos(angle) * labelRadius,
                            y: center.y + sin(angle) * labelRadius
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func problemAxisLabel(_ key: AttributeKey) -> some View {
        Text("\(key.shortCode) LVL \(baselineLevels[key] ?? 0)")
            .font(.system(size: 7.5, weight: .bold, design: .monospaced))
            .tracking(0)
            .foregroundStyle(Color.unbound.textSecondary.opacity(0.9))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private func painPointPill(
        assetName: String,
        tint: Color,
        title: String,
        detail: String,
        imagePadding: CGFloat
    ) -> some View {
        HStack(spacing: 7) {
            OnboardingAssetGlyph(
                assetName: assetName,
                tint: tint,
                size: 32,
                imagePadding: imagePadding,
                shape: .chamfered
            )

            Text(title.uppercased())
                .font(.system(size: 8.5, weight: .black, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.38))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.72), lineWidth: 1)
        )
        .accessibilityLabel(Text("\(title). \(detail)"))
    }

    private func hexRow(_ key: AttributeKey, value: Double) -> some View {
        HStack(spacing: 8) {
            Text(key.shortCode)
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 34, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.surfaceElevated.opacity(0.9))
                    Capsule()
                        .fill(Color.unbound.accent.opacity(0.82))
                        .frame(width: geo.size.width * CGFloat(value / 100))
                }
            }
            .frame(height: 6)

            Text("\(Int(value))")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)
        }
    }

    private func mutedTag(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.9)
            .foregroundStyle(Color.unbound.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.unbound.surface.opacity(0.78)))
            .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
    }

    private func baselineRow(_ key: AttributeKey) -> some View {
        let level = baselineLevels[key] ?? 0
        return HStack(spacing: 6) {
            Text(key.shortCode)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 27, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.surfaceElevated.opacity(0.82))
                    Capsule()
                        .fill(Color.unbound.accent.opacity(0.74))
                        .frame(width: geo.size.width * CGFloat(Double(level) / 8.0))
                }
            }
            .frame(height: 5)

            Text(L10n.onboardingFormat("common.level", defaultValue: "LVL %d", level))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
                .frame(width: 35, alignment: .trailing)
        }
    }
}
