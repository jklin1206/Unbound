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
        let labels = ExerciseLibrary.equipmentLabels(for: definition)
        let isBodyweightOnly = labels == ["Bodyweight"]
        if !labels.isEmpty {
            section(title: "EQUIPMENT") {
                FlowingTagStrip(labels: labels, glyph: { equipmentGlyph(for: $0) }, tint: vm.tint)
                    .opacity(isBodyweightOnly ? 0.9 : 1)
            }
        }
    }

    private func equipmentGlyph(for label: String) -> String {
        switch label {
        case "Bodyweight", "Open Space": return "figure.strengthtraining.functional"
        case "Barbell", "Smith Machine": return "figure.strengthtraining.traditional"
        case "Dumbbell", "Kettlebell":   return "dumbbell.fill"
        case "Cable", "Machine":          return "gearshape.fill"
        case "Pull-Up Bar":               return "figure.pullup"
        case "Dip Station":               return "figure.cooldown"
        case "Rings", "Band":             return "circle.dashed"
        case "Bench", "Box":              return "rectangle.fill"
        case "Sled":                      return "arrow.right.to.line"
        case "Cardio Machine":            return "figure.run"
        case "Mobility Tool":             return "figure.flexibility"
        default:                          return "wrench.and.screwdriver.fill"
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

/// A simple wrapping strip of glyph + label chips rendered as fill-only raised
/// surfaces (no pill chrome), used here for the equipment list.
private struct FlowingTagStrip: View {
    let labels: [String]
    let glyph: (String) -> String
    let tint: Color

    var body: some View {
        EquipmentWrapLayout(spacing: 8, lineSpacing: 8) {
            ForEach(labels, id: \.self) { label in
                HStack(spacing: 7) {
                    Image(systemName: glyph(label))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(label)
                        .font(Font.unbound.bodyS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surface)
                )
            }
        }
    }
}

/// Minimal flow layout so the equipment chips wrap onto multiple lines instead
/// of clipping. Uses SwiftUI `Layout` (no third-party dependency).
private struct EquipmentWrapLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = rowLayout(maxWidth: maxWidth, subviews: subviews)
        let height = rows.last.map { $0.yOffset + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        rows.removeAll()
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rowLayout(maxWidth: bounds.width, subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = subviews[item].sizeThatFits(.unspecified)
                subviews[item].place(
                    at: CGPoint(x: x, y: bounds.minY + row.yOffset),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        var yOffset: CGFloat = 0
    }

    private func rowLayout(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.items.isEmpty ? size.width : x + spacing + size.width
            if !current.items.isEmpty, needed > maxWidth {
                rows.append(current)
                current = Row()
                x = 0
            }
            if current.items.isEmpty {
                x = size.width
            } else {
                x += spacing + size.width
            }
            current.items.append(index)
            current.width = x
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }

        var y: CGFloat = 0
        for i in rows.indices {
            rows[i].yOffset = y
            y += rows[i].height + lineSpacing
        }
        return rows
    }
}
