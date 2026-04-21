import SwiftUI

struct ExerciseSwapSheet: View {
    let currentExerciseName: String
    let alternatives: [CatalogExercise]
    let onSelect: (CatalogExercise) -> Void
    var onCreateCustom: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if alternatives.isEmpty {
                    emptyState
                    if onCreateCustom != nil {
                        createNewRow
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(alternatives) { alt in
                                swapRow(alt)
                            }
                            if onCreateCustom != nil {
                                createNewRow
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.unbound.bg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SWAP EXERCISE")
                .font(Font.unbound.captionS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Replacing \(currentExerciseName)")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Same movement pattern. Filtered by your preferences.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 40)
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No alternatives available")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Add more to your available exercise library, or relax your avoid list.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var createNewRow: some View {
        Button {
            UnboundHaptics.medium()
            onCreateCustom?()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.accent.opacity(0.14)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Create new")
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Build a custom exercise")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func swapRow(_ alt: CatalogExercise) -> some View {
        Button {
            UnboundHaptics.medium()
            onSelect(alt)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Color.unbound.accent.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(alt.displayName)
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(alt.muscleGroups.map(\.rawValue).joined(separator: " · "))
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
