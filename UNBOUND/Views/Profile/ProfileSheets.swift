import SwiftUI
import PhotosUI

struct EditProfileSheet: View {
    @State private var handle: String
    @State private var selectedTitle: TitleID?
    @State private var selectedShowcaseSkillId: String?
    @State private var selectedShowcaseLiftId: String?
    @State private var errorMessage: String?
    @State private var isSaving = false

    @Environment(\.dismiss) private var dismiss

    let unlockedTitles: [TitleID]
    let showcaseSkillOptions: [ProfileShowcaseOption]
    let showcaseLiftOptions: [ProfileShowcaseOption]
    let save: (String, TitleID?, ProfileShowcaseSelection) async throws -> Void

    init(
        displayHandle: String,
        unlockedTitles: [TitleID],
        equippedTitle: TitleID?,
        showcaseSkillOptions: [ProfileShowcaseOption],
        selectedShowcaseSkillId: String?,
        showcaseLiftOptions: [ProfileShowcaseOption],
        selectedShowcaseLiftId: String?,
        save: @escaping (String, TitleID?, ProfileShowcaseSelection) async throws -> Void
    ) {
        _handle = State(initialValue: displayHandle)
        _selectedTitle = State(initialValue: equippedTitle)
        _selectedShowcaseSkillId = State(initialValue: selectedShowcaseSkillId)
        _selectedShowcaseLiftId = State(initialValue: selectedShowcaseLiftId)
        self.unlockedTitles = unlockedTitles
        self.showcaseSkillOptions = showcaseSkillOptions
        self.showcaseLiftOptions = showcaseLiftOptions
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("EDIT PROFILE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Profile")
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.unbound.surfaceElevated))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                profileField(label: "HANDLE", text: $handle, prompt: "handle")
                titleMenu
                showcaseMenu(
                    label: "SKILL",
                    selectedId: $selectedShowcaseSkillId,
                    options: showcaseSkillOptions,
                    emptyText: "PROVE A SKILL TO ADD IT HERE"
                )
                showcaseMenu(
                    label: "LIFT",
                    selectedId: $selectedShowcaseLiftId,
                    options: showcaseLiftOptions,
                    emptyText: "LOG A RANKED LIFT TO ADD IT HERE"
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.alert)
            }

            Button {
                Task { await saveTapped() }
            } label: {
                HStack {
                    Spacer()
                    if isSaving {
                        ProgressView().tint(Color.unbound.textPrimary)
                    } else {
                        Text("SAVE")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1.6)
                    }
                    Spacer()
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.unbound.bg)
    }

    private func profileField(label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            TextField(prompt, text: text)
                .textInputAutocapitalization(label == "HANDLE" ? .never : .words)
                .autocorrectionDisabled(label == "HANDLE")
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
    }

    private func showcaseMenu(
        label: String,
        selectedId: Binding<String?>,
        options: [ProfileShowcaseOption],
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)

            if options.isEmpty {
                showcaseFieldLabel(name: "None yet", tier: nil, showsChevron: false)
                    .opacity(0.68)

                Text(emptyText)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
            } else {
                Menu {
                    ForEach(options) { option in
                        Button("\(option.name) - \(option.tier.displayName)") {
                            selectedId.wrappedValue = option.id
                        }
                    }
                } label: {
                    let selected = selectedOption(selectedId.wrappedValue, options: options) ?? options.first
                    showcaseFieldLabel(
                        name: selected?.name ?? "None yet",
                        tier: selected?.tier,
                        showsChevron: true
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.plain)
                .accessibilityLabel(label.capitalized)
                .accessibilityValue(selectedOption(selectedId.wrappedValue, options: options)?.name ?? options.first?.name ?? "None yet")
            }
        }
    }

    private func showcaseFieldLabel(
        name: String,
        tier: SkillTier?,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let tier {
                    Text(tier.displayName.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(tier.rewardTextTint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func selectedOption(
        _ id: String?,
        options: [ProfileShowcaseOption]
    ) -> ProfileShowcaseOption? {
        guard let id else { return nil }
        return options.first { $0.id == id }
    }

    private var titleMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TITLE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)

            Menu {
                Button("None") {
                    selectedTitle = nil
                }

                ForEach(titleOptions, id: \.self) { titleId in
                    Button(TitleCatalog.displayName(for: titleId)) {
                        selectedTitle = titleId
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(selectedTitle.map(TitleCatalog.displayName(for:)) ?? "None")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)
            .accessibilityLabel("Profile title")
            .accessibilityValue(selectedTitle.map(TitleCatalog.displayName(for:)) ?? "None")

            if titleOptions.isEmpty {
                Text("EARN TITLES TO ADD THEM HERE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var titleOptions: [TitleID] {
        var seen = Set<TitleID>()
        return ([selectedTitle].compactMap { $0 } + unlockedTitles).filter { seen.insert($0).inserted }
    }

    private func saveTapped() async {
        isSaving = true
        errorMessage = nil
        do {
            try await save(
                handle,
                selectedTitle,
                ProfileShowcaseSelection(
                    skillId: selectedShowcaseSkillId,
                    liftId: selectedShowcaseLiftId
                )
            )
            dismiss()
        } catch {
            errorMessage = "Could not save profile."
        }
        isSaving = false
    }
}

struct RankInfoSheet: View {
    let currentTier: SkillTier
    let readiness: OverallRankTrialReadiness?
    let onStart: (OverallRankTrialDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Image(headerTier.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .shadow(color: headerTier.rewardTint.opacity(0.38), radius: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("RANK TRIAL")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text(readiness.map(rankGateTitle) ?? currentTier.displayName)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.unbound.surfaceElevated))
                    }
                    .buttonStyle(.plain)
                }

                if let readiness {
                    // Destination hero — every trial is a pilgrimage to the
                    // next location in the journey, so the gate leads with the
                    // target tier's banner art and place name.
                    if let target = readiness.targetRank {
                        trialDestinationHero(target: target)
                    }

                    RankTrialFlowStrip(readiness: readiness)

                    VStack(alignment: .leading, spacing: 10) {
                        OverallRankTrialReadinessCard(readiness: readiness) { definition in
                            dismiss()
                            onStart(definition)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private func trialDestinationHero(target: RankTitle) -> some View {
        if let asset = RankCosmetics.profileHeaderBannerAsset(for: target),
           let ui = UIImage(named: asset) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color.black.opacity(0.22), location: 0.45),
                        .init(color: Color.black.opacity(0.78), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NEXT DESTINATION")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(Color.unbound.textSecondary)
                        Text(target.bannerLocationName)
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                    }
                    Spacer()
                    Image(target.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .shadow(color: target.rewardTint.opacity(0.5), radius: 10)
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(target.rewardTint.opacity(0.30), lineWidth: 1)
            )
        }
    }

    private var headerTier: RankTitle {
        readiness?.targetRank ?? currentTier.rankTitle
    }

    private func rankGateTitle(_ readiness: OverallRankTrialReadiness) -> String {
        if let target = readiness.targetRank {
            return "\(readiness.currentRank.displayName) -> \(target.displayName)"
        }
        return "\(readiness.currentRank.displayName) Gate Cleared"
    }
}

struct RankTrialFlowStrip: View {
    let readiness: OverallRankTrialReadiness

    var body: some View {
        let met = readiness.requirements.filter(\.isMet).count
        let total = max(1, readiness.requirements.count)

        return HStack(spacing: 8) {
            step(icon: "list.bullet.clipboard.fill", label: "\(met)/\(total)", caption: "PROOFS", tint: Color.unbound.accent)
            connector
            step(icon: readiness.isReady ? "checkmark.seal.fill" : "lock.fill", label: readiness.isReady ? "READY" : "LOCKED", caption: "GATE", tint: readiness.targetRank?.rewardTextTint ?? Color.unbound.rankGold)
            connector
            step(icon: "play.fill", label: "TRIAL", caption: "WORKOUT", tint: Color.unbound.coachCyan)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var connector: some View {
        Capsule()
            .fill(Color.unbound.borderSubtle)
            .frame(width: 18, height: 2)
    }

    private func step(icon: String, label: String, caption: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.14)))
                .overlay(Circle().strokeBorder(tint.opacity(0.32), lineWidth: 1))
            VStack(spacing: 1) {
                Text(label)
                    .font(Font.unbound.monoS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(caption)
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
