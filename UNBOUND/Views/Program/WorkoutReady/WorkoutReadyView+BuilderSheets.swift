import SwiftUI

extension WorkoutReadyView {
    struct BlockEditSheet: View {
        @Environment(\.dismiss) var dismiss

        let onSave: (BlockEditDraft) -> Void

        @State var working: BlockEditDraft

        init(edit: BlockEditDraft, onSave: @escaping (BlockEditDraft) -> Void) {
            self.onSave = onSave
            _working = State(initialValue: edit)
        }


        var body: some View {
            NavigationStack {
                ZStack {
                    Color.unbound.bg.ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 16) {
                            TextField("Block title", text: $working.title)
                                .textInputAutocapitalization(.words)
                                .padding(14)
                                .background(cardBackground)
                                .accessibilityIdentifier("blockEdit.title")

                            Stepper("Sets: \(working.sets)", value: $working.sets, in: 1...12)
                                .font(Font.unbound.bodyM.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .padding(14)
                                .background(cardBackground)
                                .accessibilityIdentifier("blockEdit.sets")

                            TextField("Target (8-12, 30s, AMRAP)", text: $working.targetText)
                                .textInputAutocapitalization(.characters)
                                .padding(14)
                                .background(cardBackground)
                                .accessibilityIdentifier("blockEdit.target")

                            TextField("Notes", text: $working.notes, axis: .vertical)
                                .lineLimit(3...5)
                                .padding(14)
                                .background(cardBackground)
                                .accessibilityIdentifier("blockEdit.notes")

                            Button {
                                onSave(working)
                                dismiss()
                            } label: {
                                Text("Save Changes")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("blockEdit.save")
                        }
                        .padding(20)
                    }
                }
                .navigationTitle("Edit Block")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }
            }
        }

        var cardBackground: some View {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.unbound.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
    }

    struct BlockBuilderSheet: View {
        @Environment(\.dismiss) var dismiss

        let onAdd: (TrainingBlock) -> Void

        @State var kind: TrainingBlockKind = .custom
        @State var title = "Accessory Block"
        @State var sets = 3
        @State var targetText = "8-12"
        @State var restSeconds = 90
        @State var selectedSkillId = SkillGraph.shared.nodes.first?.id ?? ""
        @State var cardioType: CardioType = .run
        @State var notes = ""

        let supportedKinds: [TrainingBlockKind] = [.custom, .skill, .cardio, .carry, .routine]

        var body: some View {
            NavigationStack {
                ZStack {
                    Color.unbound.bg.ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 16) {
                            Picker("Block Type", selection: $kind) {
                                ForEach(supportedKinds, id: \.self) { kind in
                                    Text(kindLabel(kind)).tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("blockBuilder.kindPicker")

                            kindSpecificFields

                            Stepper("Sets: \(sets)", value: $sets, in: 1...12)
                                .font(Font.unbound.bodyM.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .padding(14)
                                .background(cardBackground)

                            TextField("Target (8-12, 30s, 10:00, 400m, 20 cal)", text: $targetText)
                                .textInputAutocapitalization(.characters)
                                .padding(14)
                                .background(cardBackground)

                            Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 0...300, step: 15)
                                .font(Font.unbound.bodyM.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .padding(14)
                                .background(cardBackground)

                            TextField("Notes", text: $notes, axis: .vertical)
                                .lineLimit(3...5)
                                .padding(14)
                                .background(cardBackground)

                            Button {
                                onAdd(makeBlock())
                                dismiss()
                            } label: {
                                Text("Add Block")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(resolvedTitle.isEmpty)
                            .accessibilityIdentifier("blockBuilder.addBlock")
                        }
                        .padding(20)
                    }
                }
                .navigationTitle("Add Block")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: kind) { _, newKind in
                    applyDefaults(for: newKind)
                }
            }
        }

        @ViewBuilder
        var kindSpecificFields: some View {
            switch kind {
            case .skill:
                Picker("Skill", selection: $selectedSkillId) {
                    ForEach(SkillGraph.shared.nodes.sorted { $0.title < $1.title }) { node in
                        Text(node.title).tag(node.id)
                    }
                }
                .pickerStyle(.navigationLink)
                .padding(14)
                .background(cardBackground)
            case .cardio:
                Picker("Cardio", selection: $cardioType) {
                    ForEach(CardioType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.navigationLink)
                .padding(14)
                .background(cardBackground)
            default:
                TextField("Block title", text: $title)
                    .textInputAutocapitalization(.words)
                    .padding(14)
                    .background(cardBackground)
            }
        }

        var resolvedTitle: String {
            switch kind {
            case .skill:
                return SkillGraph.shared.node(id: selectedSkillId)?.title ?? "Skill Practice"
            case .cardio:
                return cardioType.displayName
            default:
                return title.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        func makeBlock() -> TrainingBlock {
            if kind == .skill, let node = SkillGraph.shared.node(id: selectedSkillId) {
                var block = TrainingSessionAdapters.skillBlock(skillId: node.id, title: node.title)
                if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    block.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return block
            }

            return TrainingBlock(
                kind: kind,
                title: resolvedTitle,
                subtitle: subtitle(for: kind),
                cardioType: kind == .cardio ? cardioType : nil,
                prescriptions: [
                    TrainingBlockPrescription(
                        exerciseName: resolvedTitle,
                        sets: sets,
                        target: WorkoutReadyView.target(from: targetText),
                        restSeconds: restSeconds,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    )
                ],
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        }

        func applyDefaults(for kind: TrainingBlockKind) {
            switch kind {
            case .custom:
                title = "Accessory Block"
                sets = 3
                targetText = "8-12"
                restSeconds = 90
            case .skill:
                sets = 3
                targetText = "30s"
                restSeconds = 90
            case .cardio:
                sets = 1
                targetText = "10:00"
                restSeconds = 0
            case .carry:
                title = "Farmer Carry"
                sets = 4
                targetText = "40m"
                restSeconds = 90
            case .routine:
                title = "Mobility Routine"
                sets = 1
                targetText = "5:00"
                restSeconds = 0
            case .strength, .bodyweight:
                break
            }
        }

        func kindLabel(_ kind: TrainingBlockKind) -> String {
            switch kind {
            case .custom: return "Lift"
            case .skill: return "Skill"
            case .cardio: return "Cardio"
            case .carry: return "Carry"
            case .routine: return "Routine"
            case .strength: return "Strength"
            case .bodyweight: return "Bodyweight"
            }
        }

        func subtitle(for kind: TrainingBlockKind) -> String? {
            switch kind {
            case .cardio: return "\(cardioType.displayName) · \(targetText)"
            case .carry: return "Load, posture, distance, or time"
            case .routine: return "Timer-based sequence"
            default: return nil
            }
        }

        var cardBackground: some View {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.unbound.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
    }
}
