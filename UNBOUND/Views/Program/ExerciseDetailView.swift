import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    private var movementDefinition: MovementDefinition? {
        let resolved = MovementResolver.resolve(exercise.name)
        return MovementCatalog.definition(for: resolved.movementId)
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let movementDefinition {
                        ExerciseVisualView(definition: movementDefinition, size: .hero)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1.05, contentMode: .fit)

                        movementMetadataCard(movementDefinition)
                    }

                    ExerciseDetailSections(
                        muscleGroups: movementDefinition?.muscleGroups ?? exercise.muscleGroups,
                        sets: exercise.sets,
                        reps: exercise.reps,
                        restSeconds: exercise.restSeconds,
                        formCues: exercise.notes,
                        substitution: exercise.substitution
                    )
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(movementDefinition?.displayName ?? exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func movementMetadataCard(_ definition: MovementDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MOVEMENT")
                .font(Font.unbound.captionS)
                .tracking(1.5)
                .foregroundColor(Color.unbound.textTertiary)

            ExerciseDetailMetadataFlowLayout(spacing: 8) {
                metadataChip(definition.movementSlot.displayName, tint: Color.unbound.accent)
                metadataChip(definition.rankTemplate.displayName, tint: Color.unbound.impact)
                metadataChip(definition.loggerMode.displayName, tint: Color.unbound.textSecondary)
                ForEach(ExerciseLibrary.equipmentLabels(for: definition), id: \.self) { equipment in
                    metadataChip(equipment, tint: Color.unbound.textSecondary)
                }
            }
        }
        .padding(18)
        .background(Color.unbound.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 3)
    }

    private func metadataChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(Font.unbound.captionS)
            .foregroundColor(tint)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct ExerciseDetailMetadataFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: Exercise(
            id: "1",
            name: "Barbell Back Squat",
            muscleGroups: [.legs, .glutes, .core],
            sets: 4,
            reps: "6-8",
            restSeconds: 120,
            rpe: 8,
            notes: "Keep chest up, brace core, drive through heels.",
            substitution: "Goblet Squat or Leg Press"
        ))
    }
}
