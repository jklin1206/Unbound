import SwiftUI

/// "My Workouts" sub-tab: list-first. The saved workouts ARE the content; Quick
/// Log and Build are small secondary actions on top.
struct MyWorkoutsView: View {
    let onQuickLog: () -> Void
    let onBuild: () -> Void
    let onUseToday: (SavedWorkout) -> Void
    let onSchedule: (SavedWorkout) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    actionButton(title: "Quick Log", icon: "bolt.fill") { UnboundHaptics.medium(); onQuickLog() }
                        .accessibilityIdentifier("myWorkouts.quickLog")
                    actionButton(title: "Build", icon: "plus") { UnboundHaptics.soft(); onBuild() }
                        .accessibilityIdentifier("myWorkouts.build")
                }

                SavedWorkoutsInlineList(onUseToday: onUseToday, onSchedule: onSchedule)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(Font.unbound.bodyMStrong)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
