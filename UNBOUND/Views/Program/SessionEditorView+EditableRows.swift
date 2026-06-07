import SwiftUI

extension SessionEditorView {
    struct EditablePrescriptionRow<Visual: View>: View {
        @Binding var prescription: TrainingBlockPrescription
        let index: Int
        let canMoveUp: Bool
        let canMoveDown: Bool
        let onSwap: () -> Void
        let onMoveUp: () -> Void
        let onMoveDown: () -> Void
        let onRemove: () -> Void
        let onProgrammingChange: () -> Void
        let visual: () -> Visual

        @State var setsText: String
        @State var targetText: String
        @State var weightText: String
        @State var restText: String
        @State var rpeText: String
        @State var notesText: String
        @State var showsNotes = false

        var columns: [GridItem] {
            [GridItem(.adaptive(minimum: 86), spacing: 8, alignment: .top)]
        }

        init(
            prescription: Binding<TrainingBlockPrescription>,
            index: Int,
            canMoveUp: Bool,
            canMoveDown: Bool,
            onSwap: @escaping () -> Void,
            onMoveUp: @escaping () -> Void,
            onMoveDown: @escaping () -> Void,
            onRemove: @escaping () -> Void,
            onProgrammingChange: @escaping () -> Void,
            @ViewBuilder visual: @escaping () -> Visual
        ) {
            _prescription = prescription
            self.index = index
            self.canMoveUp = canMoveUp
            self.canMoveDown = canMoveDown
            self.onSwap = onSwap
            self.onMoveUp = onMoveUp
            self.onMoveDown = onMoveDown
            self.onRemove = onRemove
            self.onProgrammingChange = onProgrammingChange
            self.visual = visual

            let value = prescription.wrappedValue
            _setsText = State(initialValue: "\(value.sets)")
            _targetText = State(initialValue: SessionEditorView.targetEditText(value.target))
            _weightText = State(initialValue: Self.formatWeight(value.suggestedWeightKg))
            _restText = State(initialValue: "\(value.restSeconds)")
            _rpeText = State(initialValue: value.rpe.map(String.init) ?? "")
            _notesText = State(initialValue: value.notes ?? "")
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Button(action: onSwap) {
                        HStack(spacing: 10) {
                            ZStack(alignment: .topLeading) {
                                visual()
                                Text("\(index)")
                                    .font(Font.unbound.monoS.weight(.bold))
                                    .foregroundStyle(Color.unbound.bg)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(Color.unbound.coachCyan))
                                    .offset(x: -3, y: -3)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(prescription.exerciseName)
                                    .font(Font.unbound.bodyMStrong)
                                    .foregroundStyle(Color.unbound.textPrimary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.76)
                                Text(prescription.displayTargetText)
                                    .font(Font.unbound.captionS)
                                    .foregroundStyle(Color.unbound.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.unbound.textTertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    rowActionsMenu
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    editorField(label: "SETS", text: $setsText, keyboard: .numberPad)
                        .onChange(of: setsText) { _, newValue in applySets(newValue) }
                        .onSubmit { setsText = "\(prescription.sets)" }

                    editorField(label: "TARGET", text: $targetText, keyboard: .numbersAndPunctuation)
                        .onChange(of: targetText) { _, newValue in applyTarget(newValue) }

                    editorField(label: "WEIGHT", text: $weightText, suffix: "kg", keyboard: .decimalPad)
                        .onChange(of: weightText) { _, newValue in applyWeight(newValue) }
                        .onSubmit { weightText = Self.formatWeight(prescription.suggestedWeightKg) }

                    editorField(label: "REST", text: $restText, suffix: "s", keyboard: .numberPad)
                        .onChange(of: restText) { _, newValue in applyRest(newValue) }
                        .onSubmit { restText = "\(prescription.restSeconds)" }

                    editorField(label: "RPE", text: $rpeText, keyboard: .numberPad)
                        .onChange(of: rpeText) { _, newValue in applyRPE(newValue) }
                        .onSubmit { rpeText = prescription.rpe.map(String.init) ?? "" }
                }

                notesControl
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }

        var rowActionsMenu: some View {
            Menu {
                Button(action: onMoveUp) {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(!canMoveDown)

                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.unbound.bg.opacity(0.76)))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .accessibilityLabel("Exercise actions")
        }

        var notesControl: some View {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showsNotes.toggle()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "plus.circle" : "quote.bubble")
                            .font(.system(size: 12, weight: .bold))
                        Text(notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ADD CUE" : "CUES")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(0.9)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(showsNotes ? 180 : 0))
                    }
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.unbound.bg.opacity(0.62))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if showsNotes {
                    TextField("Notes or cues", text: $notesText, axis: .vertical)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(1...3)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.unbound.bg.opacity(0.72))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                        .onChange(of: notesText) { _, newValue in applyNotes(newValue) }
                }
            }
        }

        func editorField(
            label: String,
            text: Binding<String>,
            suffix: String? = nil,
            keyboard: UIKeyboardType
        ) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textTertiary)

                HStack(spacing: 4) {
                    TextField("-", text: text)
                        .font(Font.unbound.bodyS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .keyboardType(keyboard)
                        .lineLimit(1)
                        .submitLabel(.done)

                    if let suffix, !text.wrappedValue.isEmpty {
                        Text(suffix)
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
                .padding(.horizontal, 9)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.bg.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
            }
        }

        func applySets(_ text: String) {
            guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            let clamped = min(max(value, 1), 20)
            guard prescription.sets != clamped else { return }
            prescription.sets = clamped
            onProgrammingChange()
        }

        func applyTarget(_ text: String) {
            let target = SessionEditorView.target(from: text)
            guard prescription.target != target else { return }
            prescription.target = target
            onProgrammingChange()
        }

        func applyWeight(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                if prescription.suggestedWeightKg != nil || prescription.loadPercentOfBodyweight != nil {
                    prescription.suggestedWeightKg = nil
                    prescription.loadPercentOfBodyweight = nil
                    onProgrammingChange()
                }
                return
            }

            guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else { return }
            let weight = value > 0 ? value : nil
            guard prescription.suggestedWeightKg != weight else { return }
            prescription.suggestedWeightKg = weight
            prescription.loadPercentOfBodyweight = nil
            onProgrammingChange()
        }

        func applyRest(_ text: String) {
            guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            let clamped = min(max(value, 0), 600)
            guard prescription.restSeconds != clamped else { return }
            prescription.restSeconds = clamped
            onProgrammingChange()
        }

        func applyRPE(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                if prescription.rpe != nil {
                    prescription.rpe = nil
                    onProgrammingChange()
                }
                return
            }

            guard let value = Int(trimmed) else { return }
            let clamped = min(max(value, 1), 10)
            guard prescription.rpe != clamped else { return }
            prescription.rpe = clamped
            onProgrammingChange()
        }

        func applyNotes(_ text: String) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = trimmed.isEmpty ? nil : trimmed
            guard prescription.notes != notes else { return }
            prescription.notes = notes
        }

        static func formatWeight(_ value: Double?) -> String {
            guard let value else { return "" }
            let rounded = (value * 2).rounded() / 2
            if rounded.rounded() == rounded {
                return "\(Int(rounded))"
            }
            return String(format: "%.1f", rounded)
        }
    }

    struct PrescriptionTarget: Identifiable, Hashable {
        let blockIndex: Int
        let prescriptionIndex: Int
        var id: String { "\(blockIndex)-\(prescriptionIndex)" }
    }

    enum PickerRoute: Identifiable, Hashable {
        case add(blockId: String)
        case swap(PrescriptionTarget)

        var id: String {
            switch self {
            case .add(let blockId):
                return "add-\(blockId)"
            case .swap(let target):
                return "swap-\(target.id)"
            }
        }
    }

    enum CustomRoute: Identifiable, Hashable {
        case add(blockId: String)
        case swap(PrescriptionTarget)

        var id: String {
            switch self {
            case .add(let blockId):
                return "custom-add-\(blockId)"
            case .swap(let target):
                return "custom-swap-\(target.id)"
            }
        }
    }

    struct SavedWorkoutConfirmation: Identifiable {
        let id = UUID()
        let title: String
    }

    struct SkillBlockConfirmation: Identifiable {
        let id = UUID()
        let title: String
        let kind: SkillBlockKind
    }
}
