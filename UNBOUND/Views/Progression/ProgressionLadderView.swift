import SwiftUI

struct ProgressionLadderView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var familyStates: [String: ProgressionFamilyState] = [:]
    @State private var progressionStates: [ProgressionState] = []
    @State private var isLoading = true
    @State private var navigateToLog: Workout?

    private let families: [(key: String, title: String, icon: String)] = [
        ("push", "Push", "figure.arms.open"),
        ("pull", "Pull", "figure.climbing"),
        ("legs-single", "Single-Leg", "figure.strengthtraining.functional"),
        ("core-lever", "Core / Lever", "figure.core.training")
    ]

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Color.unbound.accent)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        ForEach(families, id: \.key) { family in
                            familySection(
                                key: family.key,
                                title: family.title,
                                icon: family.icon
                            )
                        }
                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Progression Paths")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let allFamily = await ProgressionStateStore.shared.allFamilyStates(userId: userId)
        familyStates = Dictionary(uniqueKeysWithValues: allFamily.map { ($0.family, $0) })
        progressionStates = await ProgressionStateStore.shared.fetchAll(userId: userId)
        isLoading = false
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LADDER")
                .font(Font.unbound.captionS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Every family has a path. Own each rung before the next one unlocks.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private func familySection(key: String, title: String, icon: String) -> some View {
        let exercises = ExerciseCatalog.progressionFamily(key)
        let state = familyStates[key]
        let unlockedTier = state?.unlockedTier ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                Text(title.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("Tier \(unlockedTier + 1) / \(exercises.count)")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            VStack(spacing: 10) {
                ForEach(exercises) { ex in
                    tierCard(
                        exercise: ex,
                        unlockedTier: unlockedTier,
                        family: key
                    )
                }
            }
        }
    }

    private func tierCard(exercise: CatalogExercise, unlockedTier: Int, family: String) -> some View {
        let tier = exercise.progressionTier ?? 0
        let state: TierCardState
        if tier < unlockedTier {
            state = .completed
        } else if tier == unlockedTier {
            state = .current
        } else {
            state = .locked
        }

        let repGuidance = progressionCriterion(for: exercise)

        return HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(bgColor(for: state).opacity(0.15))
                    .frame(width: 42, height: 42)
                Circle()
                    .strokeBorder(bgColor(for: state).opacity(0.6), lineWidth: 1)
                    .frame(width: 42, height: 42)
                switch state {
                case .completed:
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(bgColor(for: state))
                case .current:
                    Text("\(tier + 1)")
                        .font(Font.unbound.monoL)
                        .foregroundStyle(bgColor(for: state))
                case .locked:
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(bgColor(for: state))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.displayName)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(state == .locked ? Color.unbound.textSecondary : Color.unbound.textPrimary)
                    .lineLimit(1)
                if state == .current {
                    Text("Next unlock: \(repGuidance)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(2)
                } else if state == .completed {
                    Text("Completed")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.accent)
                } else {
                    Text("Locked")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    state == .current ? Color.unbound.accent : Color.unbound.border,
                    lineWidth: state == .current ? 1.5 : 1
                )
        )
        .shadow(
            color: state == .current
                ? Color.unbound.accent.opacity(0.3)
                : .clear,
            radius: state == .current ? 12 : 0
        )
        .opacity(state == .locked ? 0.55 : 1)
    }

    private func progressionCriterion(for exercise: CatalogExercise) -> String {
        let state = progressionStates.first { $0.exerciseKey == exercise.name }
        let reps = state?.targetRepMax ?? 10
        let rpe = state?.targetRPE ?? 7
        let sessions = max(2 - (state?.consecutiveSessionsAtTarget ?? 0), 1)
        return "\(sessions) session\(sessions == 1 ? "" : "s") at \(reps) reps @ RPE \(rpe)"
    }

    private func bgColor(for state: TierCardState) -> Color {
        switch state {
        case .completed: return Color.unbound.accent
        case .current:   return Color.unbound.accent
        case .locked:    return Color.unbound.textTertiary
        }
    }
}

private enum TierCardState {
    case locked, current, completed
}
