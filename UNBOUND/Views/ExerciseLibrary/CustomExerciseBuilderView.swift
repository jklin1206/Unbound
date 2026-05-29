import SwiftUI

struct CustomExerciseBuilderView: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    var onSaved: ((CustomExercise) -> Void)? = nil

    @State private var displayName: String = ""
    @State private var pattern: MovementPattern = .pushHorizontal
    @State private var classification: ExerciseClassification = .accessory
    @State private var repMin: Int = 8
    @State private var repMax: Int = 12
    @State private var notes: String = ""
    @State private var videoURLString: String = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.unbound.bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        nameCard
                        patternCard
                        classificationCard
                        repRangeCard
                        notesCard
                        videoCard
                        if let error {
                            Text(error)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.alert)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        UnboundButton(
                            title: isSaving ? "Saving..." : "Save exercise",
                            icon: "checkmark",
                            action: save
                        )
                        .disabled(!canSave || isSaving)
                        .opacity(canSave ? 1 : 0.45)
                        Spacer().frame(height: 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
    }

    private var nameCard: some View {
        card(title: "NAME") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("e.g. Zercher Squat", text: $displayName)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 2)
                if isUnmatched {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Won't count toward rank or XP")
                            .font(Font.unbound.captionS.weight(.semibold))
                    }
                    .foregroundStyle(Color.unbound.textTertiary)
                }
            }
        }
    }

    private var isUnmatched: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return MovementResolver.resolve(trimmed).isUnmatched
    }

    private var patternCard: some View {
        card(title: "MOVEMENT PATTERN") {
            Menu {
                ForEach(MovementPattern.allCases) { option in
                    Button(action: { pattern = option }) {
                        Label(option.title, systemImage: option.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: pattern.icon)
                        .foregroundStyle(Color.unbound.accent)
                    Text(pattern.title)
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
        }
    }

    private var classificationCard: some View {
        card(title: "CLASSIFICATION") {
            VStack(spacing: 8) {
                classificationRow(.upperCompound, "Upper Compound", "dumbbell.fill")
                classificationRow(.lowerCompound, "Lower Compound", "figure.strengthtraining.traditional")
                classificationRow(.accessory, "Accessory", "circle.grid.cross")
                classificationRow(.bodyweightSkill, "Bodyweight Skill", "figure.strengthtraining.functional")
            }
        }
    }

    private func classificationRow(_ value: ExerciseClassification, _ label: String, _ icon: String) -> some View {
        let isSelected = classification == value
        return Button {
            UnboundHaptics.soft()
            classification = value
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.unbound.accent : Color.unbound.textSecondary)
                    .frame(width: 22)
                Text(label)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.unbound.accent.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.unbound.accent.opacity(0.5) : Color.unbound.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var repRangeCard: some View {
        card(title: "DEFAULT REP RANGE") {
            HStack(spacing: 12) {
                stepper(label: "Min", value: $repMin, range: 1...30)
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
                stepper(label: "Max", value: $repMax, range: 1...30)
            }
        }
    }

    private func stepper(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer()
            Button {
                UnboundHaptics.soft()
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
            }
            Text("\(value.wrappedValue)")
                .font(Font.unbound.monoL)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(minWidth: 32)
            Button {
                UnboundHaptics.soft()
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private var notesCard: some View {
        card(title: "NOTES (OPTIONAL)") {
            TextField("Cueing, form reminders...", text: $notes, axis: .vertical)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
        }
    }

    private var videoCard: some View {
        card(title: "REFERENCE VIDEO URL (OPTIONAL)") {
            TextField("https://...", text: $videoURLString)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
                .textFieldStyle(.plain)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Font.unbound.captionS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private var canSave: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && repMax >= repMin
    }

    private func save() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        var url: URL?
        let trimmedURL = videoURLString.trimmingCharacters(in: .whitespaces)
        if !trimmedURL.isEmpty {
            guard let parsed = URL(string: trimmedURL),
                  parsed.scheme?.lowercased() == "http" || parsed.scheme?.lowercased() == "https" else {
                error = "Video URL must start with http:// or https://"
                return
            }
            url = parsed
        }

        let userId = services.auth.currentUserId ?? "anonymous"
        let exercise = CustomExercise(
            name: trimmedName.lowercased(),
            displayName: trimmedName,
            pattern: pattern,
            classification: classification,
            defaultRepMin: repMin,
            defaultRepMax: repMax,
            notes: notes.isEmpty ? nil : notes,
            videoURL: url,
            userId: userId
        )

        isSaving = true
        error = nil
        Task {
            do {
                try await services.customExercise.save(exercise)
                await MainActor.run {
                    isSaving = false
                    onSaved?(exercise)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    self.error = "Failed to save. Try again."
                }
            }
        }
    }
}
