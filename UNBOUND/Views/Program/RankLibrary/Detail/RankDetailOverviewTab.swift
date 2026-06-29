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

            prerequisitesSection

            skillGuideSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1. Target muscle map

    private func targetMapSection(_ definition: MovementDefinition) -> some View {
        let regions = ProgramRankTargetRegionSet.rankedRegions(node: vm.skillNode, definition: definition)
        let rankByRegion = ProgramRankTargetRegionSet.rankByRegion(from: regions)
        return section(
            title: "TARGET MAP",
            subtitle: regions.isEmpty ? "No mapped regions" : "Top movers, ranked"
        ) {
            if regions.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ProgramRankTargetBodyFigure(side: .front, rankByRegion: rankByRegion)
                        ProgramRankTargetBodyFigure(side: .back, rankByRegion: rankByRegion)
                    }
                    ProgramRankTargetRegionStrip(regions: regions)
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
        // NOT wrapped in a section card: the Form slideshow is its own full-bleed
        // panel, so an outer card would read as a box-in-a-box. The header + tabs
        // stay within the page margins; each segment owns its own framing (Form is
        // edge-to-edge, the text layers card themselves).
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "SKILL GUIDE", subtitle: segments.count > 1 ? "One layer at a time" : nil)
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
                case .assist: guideTextCard { assistContent }
                case .tips:   guideTextCard { tipsContent }
                case .fixes:  guideTextCard { mistakesContent }
                }
            }
            .animation(.easeOut(duration: 0.18), value: active)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Surface-card wrapper for the text guide layers (Assist / Tips / Fixes),
    /// matching the other section cards so they don't sit flat on black.
    private func guideTextCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
    }

    // MARK: - Segment content

    @ViewBuilder
    private var formContent: some View {
        // Skills ALWAYS prefer their own phased form infographic, keyed by node
        // id. Their generated movement twin can name-match a gym catalog movement
        // that carries no `skillId`, so the definition-first path below would
        // silently drop a skill to a plain text cue list — hiding the phase
        // images that exist for it. Resolve the node's phases up front instead.
        if vm.isSkillEntry, let node = vm.skillNode {
            let phases = FormPhaseLibrary.phases(
                for: node.id,
                fallbackTitle: node.title,
                formCues: node.formCues
            )
            if !phases.isEmpty {
                fullBleedSlideshow(phases: phases, title: node.title)
            } else if !vm.formCues.isEmpty {
                guideTextCard { cueList(vm.formCues) }
            } else {
                EmptyView()
            }
        } else if let definition = vm.movementDefinition {
            if let skillForm = skillFormGuide(for: definition) {
                fullBleedSlideshow(phases: skillForm.phases, title: skillForm.title)
            } else if !vm.formCues.isEmpty {
                // Authored form cues (exercise-specific or the linked skill node's),
                // preferred over the generic per-slot guide for covered lifts.
                guideTextCard { cueList(vm.formCues) }
            } else {
                guideTextCard {
                    SkillGuideLayerView(
                        layer: .rankExercise(definition: definition),
                        tint: vm.tint,
                        isProminent: true
                    )
                }
            }
        } else if !vm.formCues.isEmpty {
            guideTextCard { cueList(vm.formCues) }
        } else {
            EmptyView()
        }
    }

    /// The phased form infographic, broken out to the full screen width (cancels
    /// the pane's 20pt horizontal margin) so the image reads as a full-bleed hero
    /// instead of a box inside a card.
    private func fullBleedSlideshow(phases: [FormPhase], title: String) -> some View {
        FormPhaseSlideshow(phases: phases, skillTitle: title)
            .padding(.horizontal, -20)
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
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(vm.assistance.enumerated()), id: \.offset) { _, option in
                coachingItem(title: option.name, detail: option.detail, markerColor: vm.tint)
            }
        }
    }

    private var tipsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(vm.tips.enumerated()), id: \.offset) { _, tip in
                coachingItem(title: tip.title, detail: tip.detail, markerColor: vm.tint)
            }
        }
    }

    private var mistakesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(vm.commonMistakes.enumerated()), id: \.offset) { _, mistake in
                coachingItem(title: nil, detail: mistake, markerColor: Color.unbound.alert)
            }
        }
    }

    /// A calm coaching-list row: a single small dot marker, an optional bold
    /// title, and a body line. No per-item glyph icons — the dot is the only
    /// marker, so the list reads clean instead of like a row of mismatched
    /// badges.
    private func coachingItem(title: String?, detail: String, markerColor: Color) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(markerColor)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                if let title {
                    Text(title)
                        .font(Font.unbound.bodyS.weight(.heavy))
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Text(detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Prerequisites

    /// Skills only: the nodes that must be proven before this one. Each group is
    /// an AND-set; multiple groups are OR-alternatives. Marks each prereq proven
    /// vs not so the gate to this skill is explicit instead of only living as a
    /// rail in the tree.
    @ViewBuilder
    private var prerequisitesSection: some View {
        let groups = vm.prerequisiteGroups
        if !groups.isEmpty {
            section(
                title: "PREREQUISITES",
                subtitle: groups.count > 1 ? "Any one path unlocks this" : "Prove these first"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                        if index > 0 { orDivider }
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(group) { item in
                                prereqRow(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private func prereqRow(_ item: RankDetailViewModel.PrereqItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.isProven ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(item.isProven ? vm.tint : Color.unbound.textTertiary)
            Text(item.title)
                .font(Font.unbound.bodyS.weight(.semibold))
                .foregroundStyle(item.isProven ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text(item.isProven ? "PROVEN" : "LOCKED")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(item.isProven ? vm.tint : Color.unbound.textTertiary)
        }
    }

    private var orDivider: some View {
        HStack(spacing: 10) {
            Text("OR")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Rectangle()
                .fill(Color.unbound.border.opacity(0.6))
                .frame(height: 1)
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

    private func sectionHeader(title: String, subtitle: String?) -> some View {
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
    }

    private func section<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeader(title: title, subtitle: subtitle)
            // Each section's body sits in its own elevated surface card so the
            // pane reads as grouped panels instead of flat text on black.
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.unbound.border, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Equipment now renders via the shared `ExerciseEquipmentAssetStrip` (asset
// glyphs landed with the codex equipment-assets merge); the local text-chip
// fallback + flow layout are no longer needed.
