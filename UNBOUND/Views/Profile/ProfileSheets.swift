import SwiftUI
import PhotosUI

/// Everything the identity editor needs from its owner (ProfileView), so the
/// form can live inside the Profile Cosmetics hub without knowing how handle
/// or showcase state is loaded and saved.
struct ProfileIdentityEditorContext {
    let displayHandle: String
    let unlockedTitles: [TitleID]
    let equippedTitle: TitleID?
    let showcaseSkillOptions: [ProfileShowcaseOption]
    let selectedShowcaseSkillId: String?
    let showcaseLiftOptions: [ProfileShowcaseOption]
    let selectedShowcaseLiftId: String?
    let save: (String, TitleID?, ProfileShowcaseSelection) async throws -> Void
}

/// Identity editing form — handle, wearable title, showcase skill/lift.
/// Hosted as the IDENTITY surface of `ProfileCosmeticsView` (the profile-kit
/// hub); a successful save dismisses the hosting sheet.
struct ProfileIdentityForm: View {
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

    init(context: ProfileIdentityEditorContext) {
        _handle = State(initialValue: context.displayHandle)
        _selectedTitle = State(initialValue: context.equippedTitle)
        _selectedShowcaseSkillId = State(initialValue: context.selectedShowcaseSkillId)
        _selectedShowcaseLiftId = State(initialValue: context.selectedShowcaseLiftId)
        self.unlockedTitles = context.unlockedTitles
        self.showcaseSkillOptions = context.showcaseSkillOptions
        self.showcaseLiftOptions = context.showcaseLiftOptions
        self.save = context.save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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
        }
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
    var progress: OverallRankTrialProgress? = nil
    let onStart: (OverallRankTrialDefinition) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showRecords = false
    @State private var pendingRedo: RankTrialFormat? = nil

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
                    // The NextGateCard is the single destination+gate hero — it
                    // leads with the rank-banner art, the gate numeral/name, the
                    // rank transition, and Begin. (The old standalone destination
                    // hero duplicated this banner and named the same step a second,
                    // conflicting way, so it was removed.)
                    if let definition = readiness.definition {
                        NextGateCard(
                            readiness: readiness,
                            world: GateWorldCatalog.world(for: definition.format),
                            onBegin: { dismiss(); onStart(definition) }
                        )
                    }
                }

                if let progress {
                    recordsButton(progress: progress)
                }
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .sheet(isPresented: $showRecords, onDismiss: {
            // Records sheet is fully gone before we hand the redo up to Home, so
            // the workout cover presents over a single dismissing sheet (the same
            // path the NextGateCard "Begin" uses).
            guard let format = pendingRedo,
                  let definition = OverallRankTrialDefinitions.all.first(where: { $0.format == format })
            else { return }
            pendingRedo = nil
            onStart(definition)
        }) {
            if let progress {
                TrialRecordsShelf(progress: progress, onSelectGate: { format in
                    pendingRedo = format
                    showRecords = false
                })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func recordsButton(progress: OverallRankTrialProgress) -> some View {
        let passedGates = Set(progress.attempts.filter { $0.passed }.map { $0.targetRank }).count
        Button { showRecords = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "rosette")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.rankGold)
                Text("TRIAL RECORDS")
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(1.6)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer(minLength: 0)
                Text("\(passedGates)/\(RankTrialFormat.allCases.count) GATES")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.unbound.textTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rank-info-records")
    }

    private var headerTier: RankTitle {
        readiness?.targetRank ?? currentTier.rankTitle
    }

    private func rankGateTitle(_ readiness: OverallRankTrialReadiness) -> String {
        if let target = readiness.targetRank {
            // The NextGateCard below leads with the full "X → Y" transition, so the
            // header just names the rank you're climbing toward (no double arrow).
            return "\(target.displayName) Trial"
        }
        return "\(readiness.currentRank.displayName) Gate Cleared"
    }
}

/// Live rank-trial launch: the entrance cinematic (`GateEntranceView`, with a
/// still-image fallback when the Plan-3 clip is absent) walks the user into the
/// gate world, then crossfades into the real logging container. Replaces the
/// legacy `WorkoutReadyView` explainer for trials.
struct GateTrialLaunchView: View {
    let draft: TrainingSessionDraft
    let services: ServiceContainer
    var onFinished: () -> Void

    @State private var entered = false

    private var crossing: GateCrossing? {
        guard let definition = draft.programId.flatMap(OverallRankTrialDefinitions.definition) else { return nil }
        return GateCrossingCatalog.crossing(for: definition.format)
    }

    var body: some View {
        ZStack {
            if let crossing, !entered {
                GateEntranceView(crossing: crossing, onFinished: {
                    withAnimation(.easeInOut(duration: 0.4)) { entered = true }
                })
                .transition(.opacity)
            } else {
                ActiveWorkoutContainerView(draft: draft, services: services, onFinished: onFinished)
                    .transition(.opacity)
            }
        }
    }
}
