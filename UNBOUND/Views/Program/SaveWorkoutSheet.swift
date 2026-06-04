import SwiftUI

struct SaveWorkoutSheet: View {
    let draft: TrainingSessionDraft
    var existingWorkouts: [SavedWorkout] = []
    var onSave: (SavedWorkout) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var selectedRole: String?
    @State private var selectedPartnerID: UUID?

    private let roleOptions: [String] = ["push", "pull", "legs", "upper", "lower", "full-body", "core"]

    init(
        draft: TrainingSessionDraft,
        existingWorkouts: [SavedWorkout] = [],
        onSave: @escaping (SavedWorkout) -> Void
    ) {
        self.draft = draft
        self.existingWorkouts = existingWorkouts
        self.onSave = onSave
        _title = State(initialValue: draft.title)
        _selectedRole = State(initialValue: SavedWorkout.inferredSessionRole(from: draft))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        titleField
                        rolePicker
                        if !partnerCandidates.isEmpty {
                            partnerPicker
                        }
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("SAVE WORKOUT")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.coachCyan)
            Spacer()
            Text("\(exerciseCount)")
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(Color.unbound.bg)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Capsule().fill(Color.unbound.coachCyan))
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NAME")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            TextField("Workout name", text: $title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ROLE")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(roleOptions, id: \.self) { role in
                    roleChip(role)
                }
            }
        }
    }

    private func roleChip(_ role: String) -> some View {
        let isSelected = selectedRole == role
        return Button {
            UnboundHaptics.soft()
            selectedRole = role
            selectedPartnerID = nil
        } label: {
            Text(displayRole(role).uppercased())
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.unbound.accent.opacity(0.22) : Color.unbound.surface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.unbound.accent.opacity(0.5) : Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var partnerPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A/B PARTNER")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            ForEach(partnerCandidates) { workout in
                Button {
                    UnboundHaptics.soft()
                    selectedPartnerID = selectedPartnerID == workout.id ? nil : workout.id
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selectedPartnerID == workout.id ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(selectedPartnerID == workout.id ? Color.unbound.success : Color.unbound.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.title)
                                .font(Font.unbound.bodyS.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                            Text("\(workout.exerciseCount) exercises · \(displayRole(workout.sessionRole ?? ""))")
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textSecondary)
                        }
                        Spacer()
                    }
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
                .buttonStyle(.plain)
            }
        }
    }

    private var saveButton: some View {
        Button {
            let saved = SavedWorkout.from(
                draft,
                title: cleanTitle,
                sessionRole: selectedRole,
                now: Date()
            )
            var copy = saved
            copy.abPartnerID = selectedPartnerID
            onSave(copy)
            dismiss()
        } label: {
            Label("SAVE", systemImage: "square.and.arrow.down.fill")
                .font(Font.unbound.bodyMStrong)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(canSave ? Color.unbound.accent : Color.unbound.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .accessibilityIdentifier("saveWorkoutSheet.save")
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !cleanTitle.isEmpty && exerciseCount > 0
    }

    private var exerciseCount: Int {
        draft.blocks.reduce(0) { $0 + $1.prescriptions.count }
    }

    private var partnerCandidates: [SavedWorkout] {
        guard let selectedRole else { return [] }
        return existingWorkouts.filter {
            SavedWorkout.normalizedSessionRole($0.sessionRole) == selectedRole
        }
    }

    private func displayRole(_ role: String) -> String {
        switch role {
        case "full-body": return "Full body"
        default:
            return role
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }
}
