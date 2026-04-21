import SwiftUI

struct CoachActionHistoryView: View {
    @EnvironmentObject var services: ServiceContainer
    @StateObject private var executor = CoachActionExecutor.shared

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if executor.history.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("No coach actions yet")
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("When the coach makes adjustments, they'll show here.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(executor.history) { entry in
                            row(entry)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("COACH ACTIONS")
                    .font(Font.unbound.captionS)
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
    }

    private func row(_ entry: AppliedCoachAction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: entry.action))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.unbound.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.action.description)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                Text(relativeString(from: entry.appliedAt))
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Spacer()

            if executor.isWithinUndoWindow(entry), executor.undoStack.contains(where: { $0.id == entry.id }) {
                Button {
                    let userId = services.auth.currentUserId ?? "anonymous"
                    Task { try? await executor.undo(userId: userId) }
                    UnboundHaptics.medium()
                } label: {
                    Text("Undo")
                        .font(Font.unbound.captionS)
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.unbound.accent.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private func iconName(for action: CoachAction) -> String {
        switch action {
        case .swapExercise: return "arrow.left.arrow.right"
        case .insertDeload: return "leaf"
        case .adjustRepRange: return "slider.horizontal.3"
        case .acknowledgePlateau: return "exclamationmark.triangle"
        }
    }

    private func relativeString(from date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
