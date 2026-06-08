import SwiftUI

extension SessionEditorView {
    var blocksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("EXERCISES")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.7)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(exerciseCount) total")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            ForEach(Array(draft.blocks.enumerated()), id: \.element.id) { blockIndex, block in
                blockCard(block: block, blockIndex: blockIndex)
            }
        }
    }

    func blockCard(block: TrainingBlock, blockIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if block.prescriptions.isEmpty {
                emptyBlockRow()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(block.prescriptions.enumerated()), id: \.element.id) { prescriptionIndex, prescription in
                        let target = PrescriptionTarget(blockIndex: blockIndex, prescriptionIndex: prescriptionIndex)
                        EditablePrescriptionRow(
                            prescription: prescriptionBinding(for: target),
                            index: displayIndex(blockIndex: blockIndex, prescriptionIndex: prescriptionIndex),
                            canMoveUp: prescriptionIndex > 0,
                            canMoveDown: prescriptionIndex < block.prescriptions.count - 1,
                            onSwap: {
                                UnboundHaptics.soft()
                                pickerRoute = .swap(target)
                            },
                            onMoveUp: {
                                movePrescription(at: target, delta: -1)
                            },
                            onMoveDown: {
                                movePrescription(at: target, delta: 1)
                            },
                            onRemove: {
                                removePrescription(at: target)
                            },
                            onProgrammingChange: {
                                refreshDraftEstimate()
                            },
                            visual: {
                                prescriptionVisual(prescription, size: 46)
                            }
                        )
                        .id(prescription.id)
                        .accessibilityIdentifier("sessionEditor.exercise.\(blockIndex).\(prescriptionIndex).row")

                        if prescriptionIndex < block.prescriptions.count - 1 {
                            Divider().overlay(Color.unbound.border)
                        }
                    }
                }
            }
        }
    }

    func emptyBlockRow() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No exercises yet")
                .font(Font.unbound.bodyS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    func displayIndex(blockIndex: Int, prescriptionIndex: Int) -> Int {
        let previous = draft.blocks.prefix(blockIndex).reduce(0) { $0 + $1.prescriptions.count }
        return previous + prescriptionIndex + 1
    }

    @ViewBuilder
    func prescriptionVisual(_ prescription: TrainingBlockPrescription, size: CGFloat) -> some View {
        if let definition = movementDefinition(for: prescription) {
            ExerciseVisualView(definition: definition, size: size >= 96 ? .hero : .thumbnail)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            fallbackExerciseVisual(systemName: "dumbbell.fill", size: size, tint: Color.unbound.accent)
        }
    }

    func fallbackExerciseVisual(systemName: String, size: CGFloat, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size >= 96 ? 18 : 10, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
            Image(systemName: systemName)
                .font(.system(size: size >= 96 ? 32 : 18, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size >= 96 ? 18 : 10, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

}
