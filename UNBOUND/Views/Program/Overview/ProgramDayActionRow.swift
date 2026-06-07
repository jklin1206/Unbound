import SwiftUI

struct ProgramDayActionRow: View {
    let actionState: ProgramOverviewDayActionState
    let isCompleted: Bool
    let isCompletingRecoveryDay: Bool
    let onPrimary: () -> Void
    let onAddExtra: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPrimary) {
                HStack(spacing: 10) {
                    Text(actionState.label)
                        .font(Font.unbound.bodyMStrong)
                        .tracking(1.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .allowsTightening(true)
                    Image(systemName: isCompleted ? "checkmark" : "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isCompleted ? Color.unbound.surfaceElevated : Color.unbound.accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isCompleted ? Color.unbound.success.opacity(0.28) : Color.clear, lineWidth: 1)
                )
                .shadow(color: isCompleted ? Color.clear : Color.unbound.accent.opacity(0.35), radius: 10, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(!actionState.isEnabled || isCompletingRecoveryDay)
            .accessibilityIdentifier("program.startSession")

            if actionState.showsAddExtraSession {
                Button(action: onAddExtra) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(width: 52, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.unbound.success.opacity(0.22))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.unbound.success.opacity(0.38), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Session")
                .accessibilityIdentifier("program.addExtraSession")
            }

            if actionState.showsEditSession {
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .frame(width: 52, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.unbound.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit Session")
                .accessibilityIdentifier("program.editSession")
            }
        }
    }
}
