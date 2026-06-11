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
                if exerciseCount > 0 {
                    Text("\(exerciseCount) total")
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }

            ForEach(Array(draft.blocks.enumerated()), id: \.element.id) { blockIndex, block in
                blockCard(block: block, blockIndex: blockIndex)
            }

            if exerciseCount == 0 {
                Button {
                    UnboundHaptics.soft()
                    openAddExercise()
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Color.unbound.accent)
                        Text("Add your first exercise")
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sessionEditor.emptyAddExercise")
            }
        }
    }

    func blockCard(block: TrainingBlock, blockIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if block.prescriptions.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(block.prescriptions.enumerated()), id: \.element.id) { prescriptionIndex, prescription in
                        let target = PrescriptionTarget(blockIndex: blockIndex, prescriptionIndex: prescriptionIndex)
                        EditablePrescriptionRow(
                            prescription: prescriptionBinding(for: target),
                            index: displayIndex(blockIndex: blockIndex, prescriptionIndex: prescriptionIndex),
                            blockIndex: blockIndex,
                            prescriptionIndex: prescriptionIndex,
                            activeEdit: keypad.active,
                            liveBuffer: keypad.buffer,
                            onBeginEdit: { beginEdit($0) },
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
