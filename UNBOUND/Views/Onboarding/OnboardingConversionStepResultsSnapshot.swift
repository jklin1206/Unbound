import SwiftUI

// MARK: - Inserted conversion steps

struct Step_ResultsSnapshot: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private var focusZone: String {
        flow.targetAreas.first?.displayName ?? L10n.onboarding("common.fullBody", defaultValue: "Full Body")
    }
    private var frequencyLabel: String {
        flow.targetFrequency?.displayName ?? L10n.onboarding("common.fourDaysPerWeek", defaultValue: "4 days / week")
    }
    private var sessionLabel: String {
        flow.sessionLength?.displayName ?? L10n.onboarding("common.fortyFiveMinutes", defaultValue: "45 minutes")
    }
    private var equipmentLabel: String {
        if flow.equipment.contains(.fullGym) {
            return L10n.onboarding("equipment.fullGym", defaultValue: "Full gym")
        }
        if flow.equipment.contains(.bodyweight), flow.equipment.count == 1 {
            return L10n.onboarding("equipment.bodyweight", defaultValue: "Bodyweight")
        }
        if flow.equipment.isEmpty {
            return L10n.onboarding("equipment.open", defaultValue: "Equipment open")
        }
        return L10n.onboarding("equipment.mixed", defaultValue: "Mixed equipment")
    }
    private var boostedAttributes: [AttributeKey] {
        AttributeKey.allCases.filter { flow.effectiveSeededAttributes.contains($0) }
    }
    private var starterLevels: [AttributeKey: Int] {
        AttributeKey.allCases.reduce(into: [:]) { result, key in
            result[key] = flow.effectiveSeededAttributes.contains(key) ? 3 : 1
        }
    }
    private var starterTiers: [AttributeKey: RankTitle] {
        AttributeKey.allCases.reduce(into: [:]) { result, key in
            result[key] = .initiate
        }
    }
    private var starterHex: [AttributeKey: Double] {
        starterLevels.reduce(into: [:]) { result, entry in
            result[entry.key] = flow.effectiveSeededAttributes.contains(entry.key) ? 24 : 8
        }
    }

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("resultsSnapshot.title", defaultValue: "Your starting point is set."),
            subtitle: L10n.onboarding("resultsSnapshot.subtitle", defaultValue: "Day Zero is marked. The climb starts from here."),
            progress: progress,
            primaryTitle: L10n.onboarding("resultsSnapshot.primary", defaultValue: "Start my arc"),
            primaryIcon: "arrow.right",
            hudStep: .resultsSnapshot,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.unbound.surface.opacity(0.18),
                                    Color.unbound.accent.opacity(0.08),
                                    Color.unbound.surface.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    TechGridBackground(opacity: 0.12)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.onboarding("resultsSnapshot.entryMap", defaultValue: "ENTRY MAP"))
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .tracking(1.4)
                                    .foregroundStyle(Color.unbound.accent)
                                Text(L10n.onboarding("common.rank.initiate", defaultValue: "INITIATE"))
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.unbound.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .fixedSize(horizontal: true, vertical: false)
                                Text(L10n.onboarding("resultsSnapshot.entryBody", defaultValue: "This is the first mark. Everything above it has to be earned."))
                                    .font(Font.unbound.bodyS)
                                    .foregroundStyle(Color.unbound.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 10)

                            TierBadge(tier: .initiate)
                                .frame(width: 92, height: 92)
                                .shadow(color: Color.unbound.accent.opacity(0.26), radius: 18)
                        }

                        HStack(alignment: .center, spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.unbound.accent.opacity(0.10))
                                    .frame(width: 118, height: 118)
                                    .blur(radius: 18)
                                AttributeHex(
                                    current: starterHex,
                                    levels: starterLevels,
                                    tiers: starterTiers,
                                    showLabels: true,
                                    radius: 48
                                )
                            }
                            .frame(width: 118, height: 118)

                            VStack(spacing: 9) {
                                mapMetric(
                                    label: L10n.onboarding("resultsSnapshot.metric.overallLevel", defaultValue: "OVERALL LVL"),
                                    value: L10n.onboardingFormat("common.level", defaultValue: "LVL %d", 0),
                                    tint: Color.unbound.accent
                                )
                                mapMetric(label: L10n.onboarding("common.focus", defaultValue: "FOCUS"), value: focusZone.uppercased(), tint: Color.unbound.warnOrange)
                                mapMetric(label: L10n.onboarding("resultsSnapshot.metric.starterBoost", defaultValue: "STARTER BOOST"), value: boostLabel, tint: Color.unbound.rankGreen)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    signalRow(
                        assetName: "badge_art_consistency_loop",
                        label: L10n.onboarding("resultsSnapshot.signal.trainingRhythm", defaultValue: "Training rhythm"),
                        value: L10n.onboardingFormat("resultsSnapshot.signal.trainingRhythm.value", defaultValue: "%@ · %@", frequencyLabel, sessionLabel)
                    )
                    signalRow(assetName: "exercise_visual_exercise_pushup", label: L10n.onboarding("resultsSnapshot.signal.availableTools", defaultValue: "Available tools"), value: equipmentLabel)
                    signalRow(assetName: "badge_art_first_build_identity_resolved", label: L10n.onboarding("resultsSnapshot.signal.firstSpark", defaultValue: "First spark"), value: L10n.onboarding("resultsSnapshot.signal.firstSpark.value", defaultValue: "A tiny mark on the hex. Enough to begin."))
                    signalRow(assetName: "onboarding_path_rank_gates", label: L10n.onboarding("resultsSnapshot.signal.nextGate", defaultValue: "Next gate"), value: L10n.onboarding("resultsSnapshot.signal.nextGate.value", defaultValue: "Show up. Clear the wall. Climb."))
                }

                infoCallout
            }
        }
    }

    private var boostLabel: String {
        let codes = boostedAttributes.prefix(2).map(\.shortCode)
        return codes.isEmpty ? L10n.onboarding("resultsSnapshot.boost.none", defaultValue: "NONE YET") : codes.joined(separator: " + ")
    }

    private var infoCallout: some View {
        HStack(alignment: .top, spacing: 8) {
            OnboardingAssetGlyph(
                assetName: "badge_art_proof_10",
                tint: Color.unbound.accent,
                size: 25,
                imagePadding: 4,
                shape: .hexagon,
                showsCornerMark: false
            )
            .padding(.top, 1)
            Text(L10n.onboarding("resultsSnapshot.callout", defaultValue: "The blank parts are the point. Your first sessions start turning this into something real."))
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func mapMetric(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(tint.opacity(0.30), lineWidth: 1)
        )
    }

    private func signalRow(assetName: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            OnboardingAssetGlyph(
                assetName: assetName,
                tint: Color.unbound.accent,
                size: 22,
                imagePadding: 3,
                shape: .hexagon,
                showsCornerMark: false
            )
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.85), lineWidth: 1)
        )
    }
}
