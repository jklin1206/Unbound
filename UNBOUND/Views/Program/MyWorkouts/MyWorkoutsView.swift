import SwiftUI

/// "Workouts" sub-tab: list-first. The saved workouts ARE the content; Quick
/// Log and Create Workout are small secondary actions on top.
struct MyWorkoutsView: View {
    var refreshTrigger = 0
    let onQuickLog: () -> Void
    let onBuild: () -> Void
    let onStartWorkout: (SavedWorkout) -> Void
    let onSchedule: (SavedWorkout) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    actionButton(title: "Quick Log", icon: "bolt.fill", tint: Color.unbound.coachCyan) { UnboundHaptics.medium(); onQuickLog() }
                        .accessibilityIdentifier("myWorkouts.quickLog")
                    actionButton(title: "Create Workout", icon: "plus", tint: Color.unbound.accent) { UnboundHaptics.soft(); onBuild() }
                        .accessibilityIdentifier("myWorkouts.build")
                }

                SavedWorkoutsInlineList(
                    refreshTrigger: refreshTrigger,
                    onStartWorkout: onStartWorkout,
                    onSchedule: onSchedule
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
    }

    private func actionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
