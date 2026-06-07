import SwiftUI
import StoreKit

struct Step_RestartLoop: View {
    let onContinue: () -> Void

    private let previews: [OnboardingBadgePreview] = [
        .init(
            tier: .vessel,
            asset: .archetypeShredded,
            buildName: L10n.onboarding("restartLoop.preview.speed.name", defaultValue: "Speed"),
            caption: L10n.onboarding("restartLoop.preview.speed.caption", defaultValue: "fast movement"),
            levels: [.power: 18, .vitality: 27, .control: 25, .endurance: 21, .mobility: 22, .explosiveness: 26],
            tiers: [.power: .master, .vitality: .vessel, .control: .vessel, .endurance: .forged, .mobility: .forged, .explosiveness: .vessel]
        ),
        .init(
            tier: .unbound,
            asset: .archetypeVTaper,
            buildName: L10n.onboarding("restartLoop.preview.pull.name", defaultValue: "Pull"),
            caption: L10n.onboarding("restartLoop.preview.pull.caption", defaultValue: "upper-body work"),
            levels: [.power: 24, .vitality: 21, .control: 23, .endurance: 32, .mobility: 19, .explosiveness: 29],
            tiers: [.power: .vessel, .vitality: .forged, .control: .vessel, .endurance: .unbound, .mobility: .master, .explosiveness: .unbound]
        ),
        .init(
            tier: .ascendant,
            asset: .archetypeHeavyweight,
            buildName: L10n.onboarding("restartLoop.preview.power.name", defaultValue: "Power"),
            caption: L10n.onboarding("restartLoop.preview.power.caption", defaultValue: "heavy force"),
            levels: [.power: 39, .vitality: 14, .control: 22, .endurance: 20, .mobility: 11, .explosiveness: 28],
            tiers: [.power: .ascendant, .vitality: .apprentice, .control: .forged, .endurance: .forged, .mobility: .novice, .explosiveness: .unbound]
        ),
        .init(
            tier: .unbound,
            asset: .archetypeSleeper,
            buildName: L10n.onboarding("restartLoop.preview.control.name", defaultValue: "Control"),
            caption: L10n.onboarding("restartLoop.preview.control.caption", defaultValue: "skill work"),
            levels: [.power: 21, .vitality: 18, .control: 34, .endurance: 28, .mobility: 24, .explosiveness: 17],
            tiers: [.power: .forged, .vitality: .master, .control: .unbound, .endurance: .vessel, .mobility: .vessel, .explosiveness: .forged]
        )
    ]

    @State private var hasAnimated = false
    @State private var activeIndex = 0

    private var active: OnboardingBadgePreview { previews[activeIndex] }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .godRay, intensity: 0.78)
                .ignoresSafeArea()
            ParticleEmitter(config: .embers)
                .opacity(0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 44)

                VStack(spacing: 9) {
                    Text(L10n.onboarding("restartLoop.eyebrow", defaultValue: "BUILD PREVIEW"))
                        .font(Font.unbound.monoS)
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.accent)

                    Text(L10n.onboarding("restartLoop.title", defaultValue: "What you train becomes your build."))
                        .font(Font.unbound.displayM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
                .padding(.horizontal, 24)
                .opacity(hasAnimated ? 1 : 0)

                Spacer().frame(height: 12)

                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        SilhouetteView(
                            rimLight: .impact,
                            chromaticAberration: 0.35,
                            breathe: true,
                            scale: 0.72,
                            asset: active.asset
                        )
                        .frame(width: 154, height: 334)
                    }
                    .frame(width: 154, height: 334)
                    .id(active.asset.rawValue)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))

                    buildProfileCard(active)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .opacity(hasAnimated ? 1 : 0)
                .offset(y: hasAnimated ? 0 : 18)

                Spacer()

                HStack(spacing: 7) {
                    ForEach(previews.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == activeIndex ? previews[index].tier.rewardTint : Color.unbound.textTertiary.opacity(0.34))
                            .frame(width: index == activeIndex ? 18 : 6, height: 6)
                            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: activeIndex)
                    }
                }
                .padding(.bottom, 16)
                .opacity(hasAnimated ? 1 : 0)

                UnboundButton(title: L10n.onboarding("restartLoop.cta", defaultValue: "Climb the ranks"), icon: "flame.fill", action: onContinue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .opacity(hasAnimated ? 1 : 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                hasAnimated = true
            }
            startRotation()
        }
    }

    private func startRotation() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_450_000_000)
                withAnimation(.easeInOut(duration: 0.52)) {
                    activeIndex = (activeIndex + 1) % previews.count
                }
            }
        }
    }

    private func rankBadge(_ tier: SkillTier) -> some View {
        Image(tier.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 54, height: 54)
            .shadow(color: tier.rewardTint.opacity(0.34), radius: 10)
    }

    private func buildProfileCard(_ preview: OnboardingBadgePreview) -> some View {
        let peakStat = peakStat(for: preview)
        return VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.onboarding("restartLoop.profile.eyebrow", defaultValue: "PROFILE PATH"))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(preview.tier.rewardTextTint)
                    Text(preview.buildName.uppercased())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(0)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                    Text(preview.caption.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 6)

                rankBadge(preview.tier)
            }

            AttributeHex(
                current: preview.hexValues,
                levels: preview.levels,
                tiers: preview.tiers,
                showLabels: true,
                labelVariant: .profile,
                radius: 54
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 32)

            HStack(spacing: 8) {
                profileMetric(
                    label: L10n.onboarding("restartLoop.metric.rank", defaultValue: "RANK"),
                    value: preview.tier.displayName.uppercased(),
                    tint: preview.tier.rewardTextTint
                )
                profileMetric(
                    label: L10n.onboarding("restartLoop.metric.peak", defaultValue: "PEAK"),
                    value: peakStat.shortCode,
                    tint: peakStat.rewardTint
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
                .strokeBorder(preview.tier.rewardTint.opacity(0.42), lineWidth: 1)
        )
        .shadow(color: preview.tier.rewardTint.opacity(0.14), radius: 18, y: 10)
        .id("hex-\(preview.asset.rawValue)")
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private func peakStat(for preview: OnboardingBadgePreview) -> AttributeKey {
        AttributeKey.allCases.max {
            (preview.levels[$0] ?? 0) < (preview.levels[$1] ?? 0)
        } ?? .power
    }

    private func profileMetric(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.2)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.44))
        )
    }

    private func compactHexRow(_ key: AttributeKey, level: Int, tier: RankTitle, maxLevel: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(key.shortCode)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 27, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.surfaceElevated.opacity(0.82))
                    Capsule()
                        .fill(tint.opacity(0.86))
                        .frame(width: geo.size.width * CGFloat(Double(level) / Double(max(maxLevel, 1))))
                }
            }
            .frame(height: 5)

            Text(L10n.onboardingFormat("common.level", defaultValue: "LVL %d", level))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
                .frame(width: 35, alignment: .trailing)

            Image(tier.asSkillTier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .shadow(color: tier.asSkillTier.rewardTint.opacity(0.35), radius: 5)
        }
    }

}

struct OnboardingBadgePreview {
    let tier: SkillTier
    let asset: BodyAsset
    let buildName: String
    let caption: String
    let levels: [AttributeKey: Int]
    let tiers: [AttributeKey: RankTitle]

    var maxLevel: Int {
        max(levels.values.max() ?? 1, 1)
    }

    var hexValues: [AttributeKey: Double] {
        let top = Double(maxLevel)
        return levels.reduce(into: [:]) { result, entry in
            let normalized = Double(entry.value) / top
            result[entry.key] = min(96, max(16, normalized * 92))
        }
    }
}
