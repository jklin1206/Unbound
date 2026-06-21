import SwiftUI

/// Overview tab of the unified rank detail: the "understand this movement" pane.
/// Pure reference — no logging, no rank glance, no trend graph. Top to bottom:
/// the target muscle map, the equipment list, and the technique guide.
///
/// Logging + the rank ladder live in the Rank tab; PRs live in the Stats tab.
/// This pane is the calm "what is this and how do I do it" reference.
struct RankDetailOverviewTab: View {
    let vm: RankDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let definition = vm.movementDefinition {
                targetMapSection(definition)
                equipmentSection(definition)
            }

            guideSection
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
                ExerciseEquipmentAssetStrip(definition: definition, itemSize: 34, showsLabels: true)
            }
        }
    }

    // MARK: - 3. Guide / technique

    @ViewBuilder
    private var guideSection: some View {
        if let definition = vm.movementDefinition {
            if let skillForm = skillFormGuide(for: definition) {
                section(title: "SKILL FORM") {
                    FormPhaseSlideshow(phases: skillForm.phases, skillTitle: skillForm.title)
                }
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
            section(title: "SKILL FORM") {
                FormPhaseSlideshow(phases: phases, skillTitle: node.title)
            }
        } else if !vm.formCues.isEmpty {
            section(title: "FORM CUES") {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(vm.formCues.enumerated()), id: \.offset) { _, cue in
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
        }
    }

    private func skillFormGuide(for definition: MovementDefinition) -> (title: String, phases: [FormPhase])? {
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
