// UNBOUND/Views/Squads/AffinityPickerSheet.swift
import SwiftUI

struct AffinityPickerSheet: View {
    let currentAxis: AttributeKey?
    @Environment(\.dismiss) var dismiss
    @State private var selected: AttributeKey?
    @State private var isSubmitting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Pick the crew's vibe for this month.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(spacing: 10) {
                        ForEach(AttributeKey.allCases, id: \.self) { axis in
                            axisCard(axis)
                        }
                    }
                    .padding(.horizontal)

                    if let error {
                        Text(error)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.alert)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(isSubmitting ? "Saving…" : "Confirm")
                            .font(Font.unbound.bodyMStrong)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected == nil || isSubmitting)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical, 20)
            }
            .background(Color.unbound.bg.ignoresSafeArea())
            .navigationTitle("Squad Affinity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { selected = currentAxis }
    }

    // MARK: - Axis card

    private func axisCard(_ axis: AttributeKey) -> some View {
        let isSelected = selected == axis
        return Button { selected = axis } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(axis.displayName)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(
                            isSelected ? Color.unbound.accent : Color.unbound.textPrimary
                        )
                    Text(axis.trainsCopy)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.unbound.accent)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.unbound.border)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected
                        ? Color.unbound.accent.opacity(0.12)
                        : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.unbound.accent : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Submit

    @MainActor
    private func submit() async {
        guard let selected, let userId = AuthService.shared.currentUserId else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await SquadService.shared.setAffinity(selected, userId: userId)
            dismiss()
        } catch SquadError.notCaptain {
            error = "Only the captain can change affinity."
        } catch {
            self.error = "Couldn't update affinity. Try again."
        }
    }
}

#Preview {
    AffinityPickerSheet(currentAxis: .endurance)
}
