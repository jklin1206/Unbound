import SwiftUI

/// Overview tab of the unified rank detail: the "understand this movement" pane.
/// Pure reference — no logging, no rank glance, no trend graph. Top to bottom:
/// the target muscle map, the equipment list, and the technique guide.
///
/// Logging + the rank ladder live in the Rank tab; PRs live in the Stats tab.
/// This pane is the calm "what is this and how do I do it" reference.
struct RankDetailOverviewTab: View {
    let vm: RankDetailViewModel

    @State private var selectedGuideSegment: SkillGuideTab = .form

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let definition = vm.movementDefinition {
                targetMapSection(definition)
                equipmentSection(definition)
            }

            skillGuideSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1. Target muscle map

    private func targetMapSection(_ definition: MovementDefinition) -> some View {
        let targetRegions = ProgramRankTargetRegionSet.regions(for: definition)
        return section(
            title: "TARGET MAP",
            subtitle: targetRegions.isEmpty ? "No mapped regions" : nil
        ) {
            if targetRegions.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ProgramRankTargetBodyFigure(side: .front, targetRegions: targetRegions, tint: vm.tint)
                        ProgramRankTargetBodyFigure(side: .back, targetRegions: targetRegions, tint: vm.tint)
                    }
                    ProgramRankTargetRegionStrip(regions: targetRegions, tint: vm.tint)
                }
            }
        }
    }

    // MARK: - 2. Equipment

    @ViewBuilder
    private func equipmentSection(_ definition: MovementDefinition) -> some View {
        if !ExerciseLibrary.equipmentLabels(for: definition).isEmpty {
            section(title: "EQUIPMENT") {
                ExerciseEquipmentAssetStrip(definition: definition, maxItems: 4, itemSize: 48, showsLabels: true)
            }
        }
    }

    // MARK: - 3. Skill Guide (segmented: Form / Assist / Tips / Fixes)

    /// The guide segments that have content for this movement. Form is always
    /// present; Assist and Tips only when the curated guide supplies them;
    /// Fixes whenever there are common mistakes.
    private var availableSegments: [SkillGuideTab] {
        var segments: [SkillGuideTab] = [.form]
        if !vm.assistance.isEmpty { segments.append(.assist) }
        if !vm.tips.isEmpty { segments.append(.tips) }
        if !vm.commonMistakes.isEmpty { segments.append(.fixes) }
        return segments
    }

    @ViewBuilder
    private var skillGuideSection: some View {
        let segments = availableSegments
        let active = segments.contains(selectedGuideSegment) ? selectedGuideSegment : (segments.first ?? .form)
        section(title: "SKILL GUIDE", subtitle: segments.count > 1 ? "One layer at a time" : nil) {
            VStack(alignment: .leading, spacing: 16) {
                if segments.count > 1 {
                    SegmentedFilterBar(
                        items: segments,
                        title: { $0.label },
                        selection: $selectedGuideSegment
                    )
                }
                Group {
                    switch active {
                    case .form:   formContent
                    case .assist: assistContent
                    case .tips:   tipsContent
                    case .fixes:  mistakesContent
                    }
                }
                .animation(.easeOut(duration: 0.18), value: active)
            }
        }
    }

    // MARK: - Segment content

    @ViewBuilder
    private var formContent: some View {
        if let definition = vm.movementDefinition {
            if let skillForm = skillFormGuide(for: definition) {
                FormPhaseSlideshow(phases: skillForm.phases, skillTitle: skillForm.title)
            } else if !vm.formCues.isEmpty {
                // Authored form cues (exercise-specific or the linked skill node's),
                // preferred over the generic per-slot guide for covered lifts.
                cueList(vm.formCues)
            } else {
                SkillGuideLayerView(
                    layer: .rankExercise(definition: definition),
                    tint: vm.tint,
                    isProminent: true
                )
            }
        } else if let node = vm.skillNode,
                  case let phases = FormPhaseLibrary.phases(
                      for: node.id,
                      fallbackTitle: node.title,
                      formCues: node.formCues
                  ),
                  !phases.isEmpty {
            FormPhaseSlideshow(phases: phases, skillTitle: node.title)
        } else if !vm.formCues.isEmpty {
            cueList(vm.formCues)
        } else {
            EmptyView()
        }
    }

    private func cueList(_ cues: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(cues.enumerated()), id: \.offset) { _, cue in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(vm.tint)
                        .frame(width: 18)
                    Text(cue)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var assistContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(vm.assistance.enumerated()), id: \.offset) { _, option in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: option.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(vm.tint)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(vm.tint.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(option.name)
                            .font(Font.unbound.bodyS.weight(.heavy))
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text(option.detail)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var tipsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(vm.tips.enumerated()), id: \.offset) { _, tip in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: tip.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(vm.tint)
                            .frame(width: 20)
                        Text(tip.title)
                            .font(Font.unbound.bodyS.weight(.heavy))
                            .foregroundStyle(Color.unbound.textPrimary)
                    }
                    Text(tip.detail)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var mistakesContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(vm.commonMistakes.enumerated()), id: \.offset) { _, mistake in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.unbound.alert)
                        .frame(width: 18)
                    Text(mistake)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func skillFormGuide(for definition: MovementDefinition) -> (title: String, phases: [FormPhase])? {
        // Use the explicit skillId only — NOT primarySkillId. A gym lift's mere
        // skill *association* (e.g. bench press → a push skill) must not pull a
        // mismatched skill slideshow over its own authored form cues.
        guard let skillId = definition.skillId else { return nil }
        let node = SkillGraph.shared.node(id: skillId)
        let phases = FormPhaseLibrary.phases(
            for: skillId,
            fallbackTitle: node?.title ?? definition.displayName,
            formCues: node?.formCues ?? []
        )
        guard !phases.isEmpty else { return nil }
        return (node?.title ?? definition.displayName, phases)
    }

    // MARK: - Shared styling

    private func section<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Font.unbound.bodyS.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                if let subtitle {
                    Text(subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Equipment now renders via the shared `ExerciseEquipmentAssetStrip` (asset
// glyphs landed with the codex equipment-assets merge); the local text-chip
// fallback + flow layout are no longer needed.
