import SwiftUI

/// "My Workouts" sub-tab of the Train tab: the off-program surface.
/// Composes existing entry points — Quick Log (empty session), Build
/// (SessionEditorView), and Saved (SavedWorkoutsListView). Calm-list styling:
/// one hero action, the rest flat rows on bg.
struct MyWorkoutsView: View {
    let onQuickLog: () -> Void
    let onBuild: () -> Void
    let onOpenSaved: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Hero: Quick Log — the one emphasized element (accent fill).
                Button(action: { UnboundHaptics.medium(); onQuickLog() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .bold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Log")
                                .font(Font.unbound.bodyMStrong)
                            Text("Start empty · add as you go")
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textPrimary.opacity(0.8))
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.accent)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("myWorkouts.quickLog")

                // Build — flat row.
                Button(action: { UnboundHaptics.soft(); onBuild() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.unbound.textSecondary)
                        Text("Build a new workout")
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("myWorkouts.build")

                // Saved — section header + entry row (full management lives in
                // SavedWorkoutsListView, opened via onOpenSaved).
                VStack(alignment: .leading, spacing: 10) {
                    CalmSectionHeader(title: "SAVED")
                    Button(action: { UnboundHaptics.soft(); onOpenSaved() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.unbound.textSecondary)
                            Text("Your saved workouts")
                                .font(Font.unbound.bodyM)
                                .foregroundStyle(Color.unbound.textPrimary)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.unbound.textTertiary)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("myWorkouts.saved")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
    }
}
