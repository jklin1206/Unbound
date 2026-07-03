import SwiftUI

extension Step_Verdict {
    var displayHandleText: String {
        let trimmed = flow.displayHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.onboarding("verdict.handle.fallback", defaultValue: "@PLAYER") : "@\(trimmed.uppercased())"
    }

    var displayNameText: String {
        let trimmed = flow.displayHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.string(.appName, defaultValue: "UNBOUND").uppercased() : trimmed.uppercased()
    }

    var initiateTint: Color {
        RankTitle.initiate.rewardTint
    }

    var onboardingProfileImage: UIImage? {
        if isDebugOnboardingPreview, let baseline = UIImage(named: "body_baseline") {
            return baseline
        }
        return flow.profilePhoto
    }

    var onboardingAttributeLevels: [AttributeKey: Int] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
            let value = onboardingAttributeValues[key] ?? 0
            return (key, Int(value.rounded()))
        })
    }

    var onboardingAttributeTiers: [AttributeKey: RankTitle] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, RankTitle.initiate) })
    }

    var onboardingAttributeValues: [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { key in
            let base: Double = {
                switch key {
                case .power: return 16
                case .vitality: return 12
                case .control: return 14
                case .endurance: return 15
                case .mobility: return 10
                case .explosiveness: return 8
                }
            }()
            let seededBoost = flow.effectiveSeededAttributes.contains(key) ? 3.0 : 0.0
            let goalBoost: Double = {
                switch key {
                case .power:
                    return flow.goals.contains(.getStronger) ? 2 : 0
                case .endurance:
                    return flow.goals.contains(.athletic) ? 2 : 0
                case .control:
                    return flow.exerciseStyles.contains(.calisthenics) ? 2 : 0
                case .mobility:
                    return flow.exerciseStyles.contains(.mobility) ? 2 : 0
                case .explosiveness:
                    return flow.exerciseStyles.contains(.plyometrics) ? 2 : 0
                case .vitality:
                    return flow.exerciseStyles.contains(.sports) ? 2 : 0
                }
            }()
            return (key, min(22, base + seededBoost + goalBoost))
        })
    }


    var firstUnlockTitle: String {
        SkillTree.universal.nodes.first?.title ?? L10n.onboarding("verdict.firstUnlockFallback", defaultValue: "First Node")
    }

    func profileStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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

    // MARK: Build dossier — tailored narrative paragraph
    //
    // Pulls from every onboarding answer to assemble a 3–4 sentence dossier
    // that reads like a dossier, not a checklist. Static template with
    // input-driven slots.

    var buildDossierCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    OnboardingAssetGlyph(
                        assetName: "onboarding_path_protocol_dossier",
                        tint: Color.unbound.ember,
                        size: 28,
                        imagePadding: 5,
                        shape: .hexagon,
                        showsCornerMark: false
                    )
                    Text(L10n.onboarding("verdict.dossier.title", defaultValue: "YOUR BUILD DOSSIER"))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.ember)
                }

                Text(buildNarrative)
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
        }
    }

    /// Weaves focus areas, experience, and commitment into one cohesive dossier
    /// paragraph. Not AI — purely template — but reads tailored because it
    /// pulls from the user's actual answers.
    var buildNarrative: String {
        let focusPhrase = focusAreasPhrase
        let experiencePhrase = experienceDescriptor
        let commitPhrase = commitmentDescriptor
        let equipPhrase = equipmentDescriptor

        return L10n.onboardingFormat(
            "verdict.dossier.narrative",
            defaultValue: "Your first arc starts from your %@ baseline %@. Priority work: %@. With your %@ commitment, the first milestone is already in reach.",
            experiencePhrase,
            equipPhrase,
            focusPhrase,
            commitPhrase
        )
    }

    var focusAreasPhrase: String {
        let names = focusAreas.prefix(2).map { $0.lowercased() }
        switch names.count {
        case 0: return L10n.onboarding("verdict.focusPhrase.fullBody", defaultValue: "full-body recomposition")
        case 1: return names[0]
        default: return L10n.onboardingFormat("verdict.focusPhrase.pair", defaultValue: "%@ and %@", names[0], names[1])
        }
    }

    var experienceDescriptor: String {
        // Keyed off experience level — any experience enum exists downstream;
        // if not wired, return a safe default read.
        L10n.onboarding("verdict.experience.current", defaultValue: "current")
    }

    var commitmentDescriptor: String {
        switch flow.commitment {
        case 9...10: return L10n.onboarding("verdict.commitment.allIn", defaultValue: "all-in")
        case 7...8: return L10n.onboarding("verdict.commitment.serious", defaultValue: "serious")
        case 5...6: return L10n.onboarding("verdict.commitment.steady", defaultValue: "steady")
        default: return L10n.onboarding("verdict.commitment.starting", defaultValue: "starting")
        }
    }

    var equipmentDescriptor: String {
        if flow.equipment.contains(.fullGym) {
            return L10n.onboarding("verdict.equipment.fullGym", defaultValue: "with full-gym access")
        }
        if flow.equipment.contains(.bodyweight), flow.equipment.count == 1 {
            return L10n.onboarding("verdict.equipment.bodyweight", defaultValue: "with bodyweight only")
        }
        if flow.equipment.isEmpty { return "" }
        return L10n.onboarding("verdict.equipment.currentGear", defaultValue: "with your current gear")
    }

    // MARK: Build arc + supportive quote

    var archetypeCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.onboarding("verdict.arc.title", defaultValue: "YOUR BUILD ARC"))
                        .font(Font.unbound.captionS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Text(L10n.string(.appName, defaultValue: "UNBOUND").uppercased())
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.accent)
                        .tracking(1.2)
                }

                Divider().background(Color.unbound.borderSubtle)

                Text(L10n.onboardingFormat("verdict.arc.quote", defaultValue: "\"%@\"", supportiveQuote))
                    .font(Font.unbound.bodyL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Supportive tone — Phase 2g upgrades this with BuildIdentity-keyed copy.
    var supportiveQuote: String {
        L10n.onboarding("verdict.supportiveQuote", defaultValue: "Dense frame waiting to be built. Let's go.")
    }

    // MARK: Focus areas

    var focusCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.onboarding("verdict.focusAreas.title", defaultValue: "FOCUS AREAS"))
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                FlexibleWrap(spacing: 8) {
                    ForEach(focusAreas, id: \.self) { area in
                        HStack(spacing: 6) {
                            Image("onboarding_path_rank_gates")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                            Text(area)
                                .font(Font.unbound.bodyS)
                        }
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    var focusAreas: [String] {
        // Phase 2g: derive from BuildIdentity + targetAreas scan output.
        // For now, fall back to user-selected target areas or generic default.
        let areas = flow.targetAreas.prefix(4).map(\.displayName)
        return areas.isEmpty ? [L10n.onboarding("common.fullBody", defaultValue: "Full Body")] : Array(areas)
    }

    // MARK: Plan preview

    var planCard: some View {
        UnboundCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.onboarding("verdict.protocol.title", defaultValue: "YOUR ADAPTIVE PROTOCOL"))
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)

                planArc(
                    number: 1,
                    title: L10n.onboarding("verdict.protocol.foundation.title", defaultValue: "Foundation"),
                    detail: L10n.onboarding("verdict.protocol.foundation.detail", defaultValue: "Wake the base. Volume in, form locked.")
                )
                planArc(
                    number: 2,
                    title: L10n.onboarding("verdict.protocol.growth.title", defaultValue: "Growth"),
                    detail: L10n.onboarding("verdict.protocol.growth.detail", defaultValue: "Intensification. Loads climb, reps tighten.")
                )
                planArc(
                    number: 3,
                    title: L10n.onboarding("verdict.protocol.power.title", defaultValue: "Power"),
                    detail: L10n.onboarding("verdict.protocol.power.detail", defaultValue: "Realization when rank opens it.")
                )

                Divider().background(Color.unbound.borderSubtle)

                HStack(spacing: 12) {
                    statChip(assetName: "badge_art_arc_week", value: "\(sessionsPerWeek)", label: L10n.onboarding("verdict.protocol.sessionsPerWeek", defaultValue: "sessions / week"))
                    statChip(assetName: "badge_art_hour_glass", value: "\(sessionMinutes)", label: L10n.onboarding("verdict.protocol.minutesPerSession", defaultValue: "min / session"))
                }
            }
        }
    }

    func planArc(number: Int, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Color.unbound.accent, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Spacer()
        }
    }

    func statChip(assetName: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            OnboardingAssetGlyph(
                assetName: assetName,
                tint: Color.unbound.accent,
                size: 24,
                imagePadding: 5,
                shape: .hexagon,
                showsCornerMark: false
            )
            Text(value)
                .font(Font.unbound.monoM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
        )
    }

    var sessionsPerWeek: Int {
        switch flow.targetFrequency {
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case nil: return 4
        }
    }

    var sessionMinutes: Int {
        flow.sessionLength?.minutes ?? 45
    }

    func rankTint(_ rank: RankTitle) -> Color {
        rank.rewardTextTint
    }
}
