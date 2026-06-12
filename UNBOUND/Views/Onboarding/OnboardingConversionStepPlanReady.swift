import SwiftUI

struct Step_PlanReady: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private var sessionsPerWeek: Int {
        flow.targetFrequency?.numericCount ?? 4
    }

    private var sessionLengthLabel: String {
        flow.sessionLength?.displayName ?? L10n.onboarding("common.fortyFiveMinutes", defaultValue: "45 minutes")
    }

    private var planTitle: String {
        // TODO(Phase 17): wire to BuildIdentity once archetype is fully removed
        L10n.onboarding("common.arcOne", defaultValue: "ARC 1")
    }

    var body: some View {
        OnboardingScaffold(
            title: L10n.onboarding("planReady.title", defaultValue: "Your opening block is ready."),
            subtitle: L10n.onboarding("planReady.subtitle", defaultValue: "Start with honest standards. Use them to unlock the first 28-day Arc."),
            progress: progress,
            primaryTitle: L10n.onboarding("planReady.primary", defaultValue: "Unlock my training"),
            primaryIcon: "lock.open.fill",
            hudStep: .planReady,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            VStack(spacing: 12) {
                UnboundCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text(L10n.onboarding("planReady.eyebrow", defaultValue: "BLOCK READY"))
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(Color.unbound.accent)
                            Spacer(minLength: 0)
                            Text(L10n.onboarding("planReady.generated", defaultValue: "GENERATED"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.unbound.textSecondary)
                        }

                        Text("CALIBRATION WEEK")
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        OnboardingGeneratedArt(
                            candidateAssets: ["onboarding_path_protocol_dossier", "onboarding_plan_ready_hero", "body_unbound_front"],
                            fallbackAssetName: "badge_art_calibration_complete",
                            tint: Color.unbound.accent
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 148)

                        HStack(spacing: 9) {
                            planStat(label: L10n.onboarding("planReady.stat.weekly", defaultValue: "WEEKLY"), value: L10n.onboardingFormat("common.timesPerWeek.compact", defaultValue: "%dx", sessionsPerWeek))
                            planStat(label: L10n.onboarding("planReady.stat.session", defaultValue: "SESSION"), value: sessionLengthLabel.uppercased())
                            planStat(label: L10n.onboarding("common.start", defaultValue: "START"), value: "DAY 1")
                        }

                        Rectangle()
                            .fill(Color.unbound.borderSubtle)
                            .frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 7) {
                            workoutRow(index: 1, name: primaryWorkoutLabel)
                            workoutRow(index: 2, name: secondaryWorkoutLabel)
                        }
                    }
                }

                HStack(spacing: 8) {
                    insightChip(assetName: "onboarding_path_rank_gates", text: (flow.targetAreas.first?.displayName ?? L10n.onboarding("common.fullBody", defaultValue: "Full Body")).uppercased())
                    insightChip(assetName: "badge_art_first_rank_up", text: (flow.goals.first?.displayName ?? L10n.onboarding("common.buildMuscle", defaultValue: "Build Muscle")).uppercased())
                    Spacer(minLength: 0)
                }

                HStack(alignment: .top, spacing: 8) {
                    OnboardingAssetGlyph(
                        assetName: "badge_art_first_session",
                        tint: Color.unbound.accent,
                        size: 25,
                        imagePadding: 4,
                        shape: .hexagon,
                        showsCornerMark: false
                    )
                    .padding(.top, 1)
                    Text(L10n.onboarding("planReady.callout", defaultValue: "You can start today. Unlock the calibration week, 28-day Arcs, workout logging, and profile progress that keeps moving with you."))
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
        }
    }

    private var primaryWorkoutLabel: String {
        if let area = flow.targetAreas.first {
            return L10n.onboardingFormat("planReady.workout.focus", defaultValue: "%@ Focus", area.displayName)
        }
        return L10n.onboarding("planReady.workout.upperFocus", defaultValue: "Upper Focus")
    }

    private var secondaryWorkoutLabel: String {
        // TODO(Phase 17): key this off BuildIdentity once archetype is fully removed
        return L10n.onboarding("planReady.workout.lowerCoreFoundation", defaultValue: "Lower + Core Foundation")
    }

    private func planStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func workoutRow(index: Int, name: String) -> some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 18, height: 18)
                .background(
                    Circle().fill(Color.unbound.accent.opacity(0.16))
                )
            Text(name.uppercased())
                .font(Font.unbound.bodyS.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }

    private func insightChip(assetName: String, text: String) -> some View {
        HStack(spacing: 6) {
            OnboardingAssetGlyph(
                assetName: assetName,
                tint: Color.unbound.accent,
                size: 18,
                imagePadding: 3,
                shape: .hexagon,
                showsCornerMark: false
            )
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.unbound.surface.opacity(0.9))
        )
        .overlay(
            Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

private struct OnboardingGeneratedArt: View {
    let candidateAssets: [String]
    let fallbackAssetName: String
    let tint: Color

    private var resolvedImage: UIImage? {
        for name in candidateAssets {
            if let image = UIImage(named: name) {
                return image
            }
        }
        return nil
    }

    var body: some View {
        Group {
            if let image = resolvedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.16), Color.unbound.surfaceElevated.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                    OnboardingAssetGlyph(
                        assetName: fallbackAssetName,
                        tint: tint,
                        size: 72,
                        imagePadding: 8,
                        shape: .hexagon
                    )
                }
            }
        }
        .shadow(color: tint.opacity(0.22), radius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}
