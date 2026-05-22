import SwiftUI

struct Step_ProblemFrame: View {
    let onContinue: () -> Void

    @State private var hasAnimated = false

    private let baselineLevels: [AttributeKey: Int] = [
        .power: 1,
        .agility: 1,
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
                    Text("DAY ZERO")
                        .font(Font.unbound.monoS)
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.accent)

                    Text("Your stats aren't there yet.")
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
                            rimLight: .dim,
                            chromaticAberration: 0.38,
                            breathe: true,
                            scale: 0.78,
                            asset: .dormant
                        )
                        .frame(width: 178, height: 352)
                    }
                    .frame(width: 178, height: 352)
                    .opacity(hasAnimated ? 1 : 0)
                    .offset(x: hasAnimated ? 0 : -14)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            Image(SkillTier.initiate.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 46, height: 46)
                                .shadow(color: Color.unbound.textSecondary.opacity(0.28), radius: 10)

                            Text(SkillTier.initiate.displayName)
                                .font(Font.unbound.titleM)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Text("STARTING POINT")
                                .font(Font.unbound.captionS)
                                .tracking(1.1)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            AttributeHex(
                                current: baselineHexValues,
                                peak: nil,
                                levels: baselineLevels,
                                tiers: nil,
                                showLabels: true,
                                radius: 66
                            )
                            .frame(width: 154, height: 154)

                            VStack(spacing: 6) {
                                ForEach(AttributeKey.allCases, id: \.self) { key in
                                    baselineRow(key)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(hasAnimated ? 1 : 0)
                    .offset(x: hasAnimated ? 0 : 14)
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 10) {
                    Text("No rank. No map.")
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text("This is where the climb starts.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .opacity(hasAnimated ? 1 : 0)
                .offset(y: hasAnimated ? 0 : 16)

                Spacer().frame(height: 24)

                UnboundButton(title: "Show the ladder", icon: "arrow.right", action: onContinue)
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

    private var baselineHexValues: [AttributeKey: Double] {
        baselineLevels.reduce(into: [:]) { result, entry in
            result[entry.key] = Double(entry.value * 5 + 4)
        }
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

            Text("LV \(level)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
                .frame(width: 35, alignment: .trailing)
        }
    }
}

struct Step_RestartLoop: View {
    let onContinue: () -> Void

    private let previews: [OnboardingBadgePreview] = [
        .init(
            tier: .vessel,
            asset: .archetypeShredded,
            buildName: "Speed",
            caption: "fast movement",
            levels: [.power: 18, .agility: 27, .control: 25, .endurance: 21, .mobility: 22, .explosiveness: 26],
            tiers: [.power: .honed, .agility: .vessel, .control: .vessel, .endurance: .forged, .mobility: .forged, .explosiveness: .vessel]
        ),
        .init(
            tier: .unbound,
            asset: .archetypeVTaper,
            buildName: "Pull",
            caption: "upper-body work",
            levels: [.power: 24, .agility: 21, .control: 23, .endurance: 32, .mobility: 19, .explosiveness: 29],
            tiers: [.power: .vessel, .agility: .forged, .control: .vessel, .endurance: .unbound, .mobility: .honed, .explosiveness: .unbound]
        ),
        .init(
            tier: .ascendant,
            asset: .archetypeHeavyweight,
            buildName: "Power",
            caption: "heavy force",
            levels: [.power: 39, .agility: 14, .control: 22, .endurance: 20, .mobility: 11, .explosiveness: 28],
            tiers: [.power: .ascendant, .agility: .apprentice, .control: .forged, .endurance: .forged, .mobility: .novice, .explosiveness: .unbound]
        ),
        .init(
            tier: .unbound,
            asset: .archetypeSleeper,
            buildName: "Control",
            caption: "skill work",
            levels: [.power: 21, .agility: 18, .control: 34, .endurance: 28, .mobility: 24, .explosiveness: 17],
            tiers: [.power: .forged, .agility: .honed, .control: .unbound, .endurance: .vessel, .mobility: .vessel, .explosiveness: .forged]
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
                    Text("BUILD PREVIEW")
                        .font(Font.unbound.monoS)
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.accent)

                    Text("What you train becomes your build.")
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
                            scale: 0.78,
                            asset: active.asset
                        )
                        .frame(width: 178, height: 352)
                    }
                    .frame(width: 178, height: 352)
                    .id(active.asset.rawValue)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            rankBadge(active.tier)

                            Text(active.tier.displayName)
                                .font(Font.unbound.titleM)
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Text(active.caption.uppercased())
                                .font(Font.unbound.captionS)
                                .tracking(1.1)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }

                        profileHex(active)
                    }
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

                UnboundButton(title: "Climb the ranks", icon: "flame.fill", action: onContinue)
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
            .frame(width: 46, height: 46)
            .shadow(color: tier.rewardTint.opacity(0.34), radius: 10)
    }

    private func profileHex(_ preview: OnboardingBadgePreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AttributeHex(
                current: preview.hexValues,
                peak: nil,
                levels: preview.levels,
                tiers: nil,
                showLabels: true,
                radius: 66
            )
            .frame(width: 154, height: 154)

            VStack(spacing: 6) {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    compactHexRow(
                        key,
                        level: preview.levels[key] ?? 0,
                        tier: preview.tiers[key] ?? .initiate,
                        maxLevel: preview.maxLevel,
                        tint: preview.tier.rewardTint
                    )
                }
            }
        }
        .id("hex-\(preview.asset.rawValue)")
        .transition(.opacity.combined(with: .move(edge: .trailing)))
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

            Text("LV \(level)")
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

private struct OnboardingBadgePreview {
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

struct Step_UnboundFix: View {
    let onContinue: () -> Void

    @State private var hasAnimated = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            AnimeBackdrop(variant: .godRay, intensity: 0.78)
                .ignoresSafeArea()
            TechGridBackground(opacity: 0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                SystemNoticeCard(
                    eyebrow: "COUNTER-SYSTEM FOUND",
                    title: "UNBOUND",
                    message: "A progression layer for your training.",
                    accent: Color.unbound.accent,
                    icon: "sparkles",
                    pulse: pulse
                ) {
                    VStack(spacing: 10) {
                        FixChip(icon: "viewfinder", title: "BASELINE")
                        FixChip(icon: "hexagon.fill", title: "STATS")
                        FixChip(icon: "point.3.connected.trianglepath.dotted", title: "UNLOCKS")
                        FixChip(icon: "list.bullet.clipboard.fill", title: "PROTOCOL")
                    }
                }
                .padding(.horizontal, 22)
                .opacity(hasAnimated ? 1 : 0)
                .offset(y: hasAnimated ? 0 : 12)

                Spacer()

                UnboundButton(title: "Begin your arc", icon: "flame.fill", action: onContinue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .opacity(hasAnimated ? 1 : 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.86).delay(0.1)) {
                hasAnimated = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct SystemNoticeCard<Content: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    let accent: Color
    let icon: String
    let pulse: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(pulse ? 0.22 : 0.1))
                    Circle()
                        .stroke(accent.opacity(pulse ? 0.8 : 0.38), lineWidth: 1)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(accent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(eyebrow)
                        .font(Font.unbound.monoS)
                        .tracking(1.8)
                        .foregroundStyle(accent)

                    Text("NEW ENTRY")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(Font.unbound.displayM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(accent.opacity(pulse ? 0.55 : 0.24), lineWidth: 1)
        )
        .shadow(color: accent.opacity(pulse ? 0.18 : 0.08), radius: pulse ? 22 : 10)
    }
}

private struct SystemMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(Font.unbound.monoS)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer(minLength: 12)
            Text(value)
                .font(Font.unbound.monoS)
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.52))
        )
    }
}

private struct FixChip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 24, height: 24)

            Text(title)
                .font(Font.unbound.monoS)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textPrimary)

            Spacer(minLength: 0)

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color.unbound.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.18), lineWidth: 1)
        )
    }
}

#Preview("Problem") {
    Step_ProblemFrame(onContinue: {})
}

#Preview("Arc Status") {
    Step_RestartLoop(onContinue: {})
}

#Preview("Fix") {
    Step_UnboundFix(onContinue: {})
}
