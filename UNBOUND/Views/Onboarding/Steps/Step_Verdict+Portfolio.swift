import SwiftUI

extension Step_Verdict {
    var portfolioSheet: some View {
        VStack(alignment: .center, spacing: 14) {
            revealHeader
            initiateAvatarReveal
            initiateIdentityBlock
            initiateTierPlate
            dayZeroMilestoneBand
            projectionReveal
            profileHexReveal
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 10)
        .opacity(hasAnimated ? 1 : 0)
        .scaleEffect(hasAnimated ? 1 : 0.97)
    }

    var revealHeader: some View {
        VStack(spacing: 2) {
            Text(L10n.string(.appName, defaultValue: "UNBOUND").uppercased())
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .tracking(5.0)
                .foregroundStyle(Color.unbound.accent)
                .multilineTextAlignment(.center)

            Text(L10n.onboarding("verdict.rankRevealed", defaultValue: "RANK REVEALED"))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(initiateTint)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(initiateTint.opacity(0.12)))
                .overlay(Capsule().strokeBorder(initiateTint.opacity(0.42), lineWidth: 1))
                .padding(.top, 4)

            Text(L10n.onboarding("verdict.dayZero", defaultValue: "DAY ZERO"))
                .font(.system(size: 50, weight: .black))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    var initiateAvatarReveal: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            initiateTint.opacity(0.34),
                            Color.unbound.accent.opacity(0.16),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 142
                    )
                )
                .frame(width: 250, height: 250)
                .blur(radius: 14)

            CosmeticAvatar(
                tier: .initiate,
                size: 222,
                image: onboardingProfileImage,
                letterFallback: "U"
            )
            .shadow(color: initiateTint.opacity(0.46), radius: 26)
            .scaleEffect(hasAnimated ? 1 : 0.82)
            .rotation3DEffect(.degrees(hasAnimated ? 0 : -8), axis: (x: 0, y: 1, z: 0))

            Circle()
                .trim(from: 0, to: hasAnimated ? 1 : 0.08)
                .stroke(
                    AngularGradient(
                        colors: [.clear, initiateTint.opacity(0.2), Color.unbound.impact, initiateTint.opacity(0.2), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 246, height: 246)
                .rotationEffect(.degrees(hasAnimated ? 360 : 0))
                .animation(.easeOut(duration: 1.1).delay(0.12), value: hasAnimated)
        }
        .frame(height: 232)
    }

    var initiateIdentityBlock: some View {
        VStack(spacing: 8) {
            Text(L10n.onboarding("verdict.profileCreated", defaultValue: "PROFILE CREATED"))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(initiateTint)
                .padding(.horizontal, 13)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.unbound.bg.opacity(0.88)))
                .overlay(Capsule().strokeBorder(initiateTint.opacity(0.44), lineWidth: 1))

            Text(L10n.string(.appName, defaultValue: "UNBOUND").uppercased())
                .font(.system(size: 34, weight: .black))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(displayHandleText)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(initiateTint)
                .lineLimit(1)
        }
    }

    var initiateTierPlate: some View {
        HStack(spacing: 13) {
            Spacer(minLength: 0)

            Image(RankTitle.initiate.asSkillTier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.onboarding("verdict.currentRank", defaultValue: "CURRENT RANK"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(initiateTint)
                Text(L10n.onboarding("common.rank.initiate", defaultValue: "INITIATE"))
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(initiateTint.opacity(0.58), lineWidth: 1.2)
        )
        .shadow(color: initiateTint.opacity(hasAnimated ? 0.42 : 0), radius: 24)
        .scaleEffect(hasAnimated ? 1 : 0.94)
    }

    var dayZeroMilestoneBand: some View {
        VStack(spacing: 10) {
            VStack(alignment: .center, spacing: 4) {
                Text(L10n.onboarding("verdict.potentialRead", defaultValue: "POTENTIAL READ"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(initiateTint)
                Text(L10n.onboarding("verdict.potentialRead.body", defaultValue: "High growth potential detected. Initiate is where your record starts, not where it ends."))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 8) {
                revealPill(L10n.onboarding("common.dayZero.compact", defaultValue: "DAY 0"))
                revealPill(L10n.onboardingFormat("common.timesPerWeek.long", defaultValue: "%dx / WEEK", sessionsPerWeek))
                revealPill(L10n.onboarding("verdict.firstArc", defaultValue: "FIRST ARC"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(initiateTint.opacity(0.50), lineWidth: 1)
        )
    }

    var onboardingProofGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            revealStatTile(label: L10n.onboarding("common.start", defaultValue: "START"), value: L10n.onboarding("common.dayZero.compact", defaultValue: "DAY 0"), assetName: "badge_art_streak_flame", tint: Color.unbound.ember)
            revealStatTile(label: L10n.onboarding("verdict.monthOne", defaultValue: "MONTH ONE"), value: L10n.onboardingFormat("common.timesPerWeek.long", defaultValue: "%dx / WEEK", sessionsPerWeek), assetName: "badge_art_arc_week", tint: Color.unbound.coachCyan)
            revealStatTile(label: L10n.onboarding("verdict.buildFocus", defaultValue: "BUILD FOCUS"), value: focusAreas.first?.uppercased() ?? L10n.onboarding("common.fullBody", defaultValue: "Full Body").uppercased(), assetName: "badge_art_first_build_identity_resolved", tint: initiateTint)
            revealStatTile(label: L10n.onboarding("verdict.firstUnlock", defaultValue: "FIRST UNLOCK"), value: firstUnlockTitle.uppercased(), assetName: "exercise_visual_exercise_pushup", tint: Color.unbound.accent)
        }
    }

    var profileHexReveal: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L10n.onboarding("verdict.buildHex", defaultValue: "BUILD HEX"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text(L10n.onboarding("verdict.baseline", defaultValue: "BASELINE"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(initiateTint)
            }

            AttributeHex(
                current: onboardingAttributeValues,
                levels: onboardingAttributeLevels,
                tiers: onboardingAttributeTiers,
                showLabels: true,
                labelVariant: .profile,
                radius: 82
            )
            .padding(.horizontal, 42)
            .padding(.top, 42)
            .padding(.bottom, 46)

            attributeLevelGrid

            Text(L10n.onboarding("verdict.buildHex.body", defaultValue: "This is just the baseline. Every session makes the card harder to ignore."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle.opacity(0.9), lineWidth: 1)
        )
    }

    var attributeLevelGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 7)], spacing: 7) {
            ForEach(AttributeKey.allCases, id: \.self) { key in
                let level = onboardingAttributeLevels[key] ?? 1
                HStack(spacing: 6) {
                    Text(key.shortCode)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(key.rewardTint)
                    Spacer(minLength: 0)
                    Text(L10n.onboardingFormat("common.level", defaultValue: "LVL %d", level))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.055))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(key.rewardTint.opacity(0.24), lineWidth: 1)
                )
            }
        }
    }

    func revealStatTile(label: String, value: String, assetName: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint)
                .frame(width: 4, height: 42)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                OnboardingAssetGlyph(
                    assetName: assetName,
                    tint: tint,
                    size: 28,
                    imagePadding: 5,
                    shape: .hexagon,
                    showsCornerMark: false
                )
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.42), lineWidth: 1)
        )
    }

    func revealPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(Color.unbound.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(initiateTint.opacity(0.24), lineWidth: 1))
    }

}
